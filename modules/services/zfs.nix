{ ... }:

{
    services = {
        zfs = {
            autoScrub = {
                enable = true;
                pools = [ "rpool" ];
            };
            autoSnapshot = {
                enable = true;
                weekly = 1;
            };
        };
    };
}