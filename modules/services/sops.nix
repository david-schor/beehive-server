{ ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/nix/secret/initrd/ssh_host_ed25519_key" ];
    secrets = {
      "user-password".neededForUsers = true;
      "user-password" = {};
      "vaultwarden-password" = {};
      "infomaniak-api-token" = {};
      "pihole-password" = {};
    };
    # https://github.com/Mic92/sops-nix/issues/427
    gnupg.sshKeyPaths = [];
  };
}