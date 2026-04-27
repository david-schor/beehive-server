{ pkgs, config, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "docker.io/library/nextcloud";
    imageDigest = "sha256:c57837af3cfd7d2c204e3ded81d1f87c0a164e334c9876adf666b973c57e6f78";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; #TODO
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{

}