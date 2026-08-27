{ ... }:

# TODO: need to buy a external ssd first (rsync.net is too expensive)
{
  services.syncoid = {
    enable = false;
    commands."rpool/data" = {
      target = "backup-host:backup-pool/data";
      recursive = true;
    };
  };
}