{ pkgs, config, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "docker.io/vaultwarden/server";
    imageDigest = "sha256:5de9ad29fb65f6eb3c6dc04165fca45ef9440aa9ccc6851f2f1b35fb5384c38d";
    hash = "sha256-04bd3XZoMFZLqqdca3SGMSaDj5SGVtEkP7WO5ITnP8w=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  sops.templates.vaultwarden-k3s-secret = {
    path = "/var/lib/rancher/k3s/server/manifests/vaultwarden-secret.yaml";
    content = builtins.toJSON {
      apiVersion = "v1";
      kind = "Secret";
      metadata.name = "vaultwarden-secrets";
      type = "Opaque";
      stringData = {
        admin-token = config.sops.placeholder."vaultwarden-password";
      };
    };
  };

  services.k3s = {
    images = [ image ];
    manifests = {
      vaultwarden-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "vaultwarden";
          labels."app.kubernetes.io/name" = "vaultwarden";
        };
        spec = {
          replicas = 1;
          selector.matchLabels."app.kubernetes.io/name" = "vaultwarden";
          template = {
            metadata.labels."app.kubernetes.io/name" = "vaultwarden";
            spec = {
              containers = [
                {
                  name = "vaultwarden";
                  image = "${image.imageName}:${image.imageTag}";
                  ports = [
                    { containerPort = 80; }
                  ];
                  env = [
                    {
                      name = "SIGNUPS_ALLOWED";
                      value = "false";
                    }
                    {
                      name = "ADMIN_TOKEN";
                      valueFrom.secretKeyRef = {
                        name = "vaultwarden-secrets";
                        key = "admin-token";
                      };
                    }
                  ];
                  volumeMounts = [
                    {
                      mountPath = "/data";
                      name = "data";
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "data";
                  persistentVolumeClaim.claimName = "vaultwarden-data";
                }
              ];
            };
          };
        };
      };

      vaultwarden-pvc.content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "vaultwarden-data";
          labels."app.kubernetes.io/name" = "vaultwarden";
        };
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          storageClassName = "local-path";
          resources.requests.storage = "1Gi";
        };
      };

      vaultwarden-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "vaultwarden";
          labels."app.kubernetes.io/name" = "vaultwarden";
        };
        spec = {
          selector."app.kubernetes.io/name" = "vaultwarden";
          ports = [
            {
              name = "http";
              protocol = "TCP";
              port = 80;
              targetPort = 80;
            }
          ];
        };
      };
    };
  };
}