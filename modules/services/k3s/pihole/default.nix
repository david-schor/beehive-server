{ pkgs, config, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "pihole/pihole";
    imageDigest = "sha256:300cc8f9e966b00440358aafef21f91b32dfe8887e8bd9a6193ed1c4328655d4";
    hash = "sha256-td8nrc/RDrMkyCmbZqVunSsC/z6I80lxszr7BTHXTI8=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  sops.templates.pihole-k3s-secret = {
    path = "/var/lib/rancher/k3s/server/manifests/pihole-secret.yaml";
    content = builtins.toJSON {
      apiVersion = "v1";
      kind = "Secret";
      metadata.name = "pihole-secrets";
      type = "Opaque";
      stringData = {
        webpassword = config.sops.placeholder."pihole-password";
      };
    };
  };

  services.k3s = {
    images = [ image ];
    manifests = {
      pihole-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "pihole";
          labels."app.kubernetes.io/name" = "pihole";
        };
        spec = {
          replicas = 1;
          selector.matchLabels."app.kubernetes.io/name" = "pihole";
          template = {
            metadata.labels."app.kubernetes.io/name" = "pihole";
            spec = {
              hostNetwork = true;
              dnsPolicy = "ClusterFirstWithHostNet";

              affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [
                {
                  labelSelector.matchLabels."app.kubernetes.io/name" = "pihole";
                  topologyKey = "kubernetes.io/hostname";
                }
              ];

              containers = [
                {
                  name = "pihole";
                  image = "${image.imageName}:${image.imageTag}";
                  env = [
                    {
                      name = "FTLCONF_webserver_api_password";
                      valueFrom.secretKeyRef = {
                        name = "pihole-secrets";
                        key = "webpassword";
                      };
                    }
                    { name = "TZ";                    value = "Europe/Zurich"; }
                    { name = "DNSMASQ_LISTENING";      value = "all"; }
                    { name = "FTLCONF_webserver_port"; value = "8080"; }
                  ];
                  volumeMounts = [
                    { mountPath = "/etc/pihole";    name = "pihole-data"; }
                    { mountPath = "/etc/dnsmasq.d"; name = "dnsmasq-data"; }
                  ];
                }
              ];
              volumes = [
                { name = "pihole-data";  persistentVolumeClaim.claimName = "pihole-data"; }
                { name = "dnsmasq-data"; persistentVolumeClaim.claimName = "pihole-dnsmasq"; }
              ];
            };
          };
        };
      };

      pihole-pvc-data.content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "pihole-data";
          labels."app.kubernetes.io/name" = "pihole";
        };
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          storageClassName = "local-path";
          resources.requests.storage = "500Mi";
        };
      };

      pihole-pvc-dnsmasq.content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "pihole-dnsmasq";
          labels."app.kubernetes.io/name" = "pihole";
        };
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          storageClassName = "local-path";
          resources.requests.storage = "100Mi";
        };
      };

      pihole-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "pihole";
          labels."app.kubernetes.io/name" = "pihole";
        };
        spec = {
          selector."app.kubernetes.io/name" = "pihole";
          type = "ClusterIP";
          ports = [
            { name = "http"; protocol = "TCP"; port = 80; targetPort = 8080; }
          ];
        };
      };

      pihole-ingress.content = {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "pihole";
          labels."app.kubernetes.io/name" = "pihole";
          annotations = {
            "kubernetes.io/ingress.class" = "caddy";
          };
        };
        spec = {
          ingressClassName = "caddy";
          rules = [
            {
              host = "pihole.schor.me";
              http.paths = [
                {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    name = "pihole";
                    port.number = 80;
                  };
                }
              ];
            }
          ];
        };
      };
    };
  };
}