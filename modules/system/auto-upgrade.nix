{ vars, ... }:

{
    system.autoUpgrade = {
        enable = true;
        flake = "github:david-schor/beehive-server";
        flags = [
            "--print-build-logs"
            "--commit-lock-file"
        ];
        dates = "*-*-01 01:00:00";
        randomizedDelaySec = "1h";
    };

    systemd.services.nixos-upgrade.environment = {
        GIT_AUTHOR_NAME = vars.fullName;
        GIT_AUTHOR_EMAIL = vars.userEmail;
        GIT_COMMITTER_NAME = vars.fullName;
        GIT_COMMITTER_EMAIL = vars.userEmail;
    };
}