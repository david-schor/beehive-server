#!/usr/bin/env bash
set -e

# Thanks to https://oblivious.observer

pprint () {
    local cyan="\e[96m"
    local default="\e[39m"
    local timestamp
    timestamp=$(date +%FT%T.%3NZ)
    echo -e "${cyan}${timestamp} $1${default}" 1>&2
}

pprint "Available disks:"
DISKS=()
while read -r name size type tran; do
    if [[ "$type" == "disk" && "$tran" != "usb" && "$tran" != "loop" ]]; then
        DISKS+=("$name ($size)")
    fi
done < <(lsblk -dn -o NAME,SIZE,TYPE,TRAN)

if [ ${#DISKS[@]} -eq 0 ]; then
    pprint "No internal disks found!"
    exit 1
fi

PS3="Select disk to install on: "
select DISK_CHOICE in "${DISKS[@]}"; do
    [ -n "$DISK_CHOICE" ] || { pprint "Invalid choice, try again."; continue; }
    DISK_NAME=$(echo "$DISK_CHOICE" | awk '{print $1}')
    DISK="/dev/$DISK_NAME"
    pprint "Installing system on $DISK"
    break
done

while true; do
    read -rp "Enter additional swap size (e.g. 512MiB, 8GiB): " INPUT

    if [[ $INPUT =~ ^([1-9][0-9]*)(GiB|MiB)$ ]]; then
        VALUE="${BASH_REMATCH[1]}"
        UNIT="${BASH_REMATCH[2]}"

        if [[ $UNIT == "GiB" ]]; then
            TOTAL_MIB=$(( VALUE * 1024 + 512 ))
        else
            TOTAL_MIB=$(( VALUE + 512 ))
        fi

        SWAP_SIZE="${TOTAL_MIB}MiB"

        pprint "Swap end position set to $SWAP_SIZE"
        break
    else
        pprint "Invalid input. Please use format like 512MiB or 8GiB."
    fi
done

read -rp "> Do you want to wipe all data on $DISK ?" -n 1 -r
echo
if [[ "$REPLY" =~ ^[Yy]$ ]]
then
    wipefs -af "$DISK"
    sgdisk -Zo "$DISK"
    partprobe "$DISK"
else
    exit 1
fi

pprint "Partitioning rpool"
parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MiB 512MiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart swap 512MiB $SWAP_SIZE
parted $DISK -- mkpart rpool $SWAP_SIZE 100%

pprint "Running partprobe on $DISK"
partprobe $DISK

pprint "Create pool"
zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O xattr=sa \
  -O acltype=posixacl \
  -O atime=off \
  -O mountpoint=none \
  -O encryption=on \
  -O keyformat=passphrase \
  -O keylocation=prompt \
  rpool ${DISK}p3

pprint "Create datasets"
zfs create -o mountpoint=legacy rpool/root
zfs create -o mountpoint=legacy rpool/data
zfs create -o mountpoint=legacy rpool/nix
zfs create -o mountpoint=legacy rpool/persist

# perf degrades if >80% full
zfs create -o refreservation=10G -o mountpoint=none rpool/reserved

mkswap -L swap ${DISK}p2
swapon ${DISK}p2

pprint "List datasets"
zfs list

pprint "Mount datasets"
mount -t zfs rpool/root /mnt
mkdir -pv /mnt/{boot,nix,data,etc/ssh,var/{lib,log}}
mount -t zfs rpool/nix /mnt/nix
mkdir -pv /mnt/nix/persist
mount -t zfs rpool/persist /mnt/nix/persist
mount -t zfs rpool/data /mnt/data
mkdir -pv /mnt/nix/secret/initrd
chmod 0700 /mnt/nix/secret

pprint "Mount boot partition"
mkfs.fat -F 32 -n boot ${DISK}p1
mkdir -p /mnt/boot
mount -o umask=077 ${DISK}p1 /mnt/boot

pprint "Generate SSH host key"
ssh-keygen -t ed25519 -N "" -C "" -f /mnt/nix/secret/initrd/ssh_host_ed25519_key

pprint "Generate key for sops-nix"
AGE_KEY=$(sudo nix-shell --extra-experimental-features flakes -p ssh-to-age --run \
  'cat /mnt/nix/secret/initrd/ssh_host_ed25519_key.pub | ssh-to-age')

pprint "Read machine id"
HOST_ID=$(head -c8 /etc/machine-id)

pprint "Read UUID of swap partition"
UUID_SWAP=$(lsblk -rno PKNAME,PARTUUID,FSTYPE | awk -v disk="$DISK_NAME" '$1==disk && $3=="swap" {print $2}')

echo
echo "========================================"
echo "Add these vars to your repo"
echo "----------------------------------------"
pprint "hostId   = \"$HOST_ID\""
pprint "uuidSwap = \"$UUID_SWAP\""
pprint "sops-age key   = \"$AGE_KEY\""
echo "========================================"
echo
echo "after pushing the changes you can install nixos and after this, run 'sbctl verify'. also enable secure boot after reboot"