#!/usr/bin/env bash
set -e

pprint () {
    local cyan="\e[96m"
    local default="\e[39m"
    # ISO8601 timestamp + ms
    local timestamp
    timestamp=$(date +%FT%T.%3NZ)
    echo -e "${cyan}${timestamp} $1${default}" 1>&2
}

echo "These are the disks available:"
ls -l /dev/disk/by-id/ | awk '{print $11, $10, $9}' | tr -d './' | column -t
echo

# Select PRIMARY disk (500GB)
echo "Select the PRIMARY disk (important data, 500GB):"
select ENTRY in $(ls /dev/disk/by-id/ | grep -v part);
do
    PRIMARY_DISK="/dev/disk/by-id/$ENTRY"
    echo "Primary disk: $PRIMARY_DISK"
    break
done

# Select SECONDARY disk (250GB)
echo "Select the SECONDARY disk (bulk, 250GB):"
select ENTRY in $(ls /dev/disk/by-id/ | grep -v part); 
do
    SECONDARY_DISK="/dev/disk/by-id/$ENTRY"
    # Prevent selecting same disk
    if [ "$SECONDARY_DISK" = "$PRIMARY_DISK" ]; then
        echo "Cannot select the same disk!"
        continue
    fi
    echo "Secondary disk: $SECONDARY_DISK"
    break
done

pprint "Partitioning primary"
parted $PRIMARY_DISK -- mklabel gpt
parted $PRIMARY_DISK -- mkpart ESP fat32 1MiB 512MiB
parted $PRIMARY_DISK -- set 1 esp on
parted $PRIMARY_DISK -- mkpart primary 512MiB 100%

pprint "Partitioning secondary"
parted $SECONDARY_DISK -- mklabel gpt
parted $SECONDARY_DISK -- mkpart primary 1MiB 100%

pprint "Running partprobe on $PRIMARY_DISK"
partprobe $PRIMARY_DISK

pprint "Running partprobe on $SECONDARY_DISK"
partprobe $SECONDARY_DISK

pprint "Create zfs pool"
# primary pool
zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O mountpoint=none \
  primary ${PRIMARY_DISK}p2

# secondary pool
zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O mountpoint=none \
  secondary ${SECONDARY_DISK}p1

pprint "Create datasets"
zfs create -o mountpoint=legacy primary/root
zfs create -o mountpoint=legacy primary/data

zfs create -o mountpoint=legacy secondary/root
zfs create -o mountpoint=legacy secondary/data

pprint "Mount datasets"
mount -t zfs primary/root /mnt
mount -t zfs primary/data /mnt/data

mount -t zfs secondary/root /mnt
mount -t zfs secondary/data /mnt/data

mkdir -p /mnt/primary
mkdir -p /mnt/secondary

mount -t zfs primary/data /mnt/data
mount -t zfs secondary/data /mnt/data

pprint "Mount boot partition"
mkfs.fat -F 32 -n boot ${PRIMARY_DISK}p1
mkdir -p /mnt/boot
mount ${PRIMARY_DISK}p1 /mnt/boot

echo "done"