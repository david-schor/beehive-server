{ ... }:

{
    services = {
        zfs = {
            autoScrub = {
                enable = true;
                pools = [ "rpool" ];
            };
        };
    };
}