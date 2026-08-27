{ ... }:

{
  services.sanoid = {
    enable = true;
    templates.backup = {
      hourly = 36;
      daily = 30;
      monthly = 3;
      autoprune = true;
      autosnap = true;
    };

    datasets."rpool/data" = {
      useTemplate = [ "backup" ];
    };
    datasets."rpool/persist" = {
      useTemplate = [ "backup" ];
    };
  };
}