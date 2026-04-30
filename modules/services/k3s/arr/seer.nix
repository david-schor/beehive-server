{ pkgs, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "seerr/seerr";
    imageDigest = "sha256:c4cbd5121236ac2f70a843a0b920b68a27976be57917555f1c45b08a1e6b2aad"; 
    hash = "sha256-vaq0YLAi6jABwqs/TbCt+ksOhwExMNqU1uKkkvvf8jk=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  services.k3s.images = [ image ];

  services.k3s.manifests = {
    seerr-deployment.content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "seerr";
        labels."app.kubernetes.io/name" = "seerr";
      };
      spec = {
        replicas = 1;
        selector.matchLabels."app.kubernetes.io/name" = "seerr";
        template = {
          metadata.labels."app.kubernetes.io/name" = "seerr";
          spec = {
            containers = [
              {
                name = "seerr";
                image = "${image.imageName}:${image.imageTag}";
                env = [
                  { name = "TZ"; value = "Europe/Zurich"; }
                  { name = "LOG_LEVEL"; value = "debug"; }
                ];
                ports = [ { containerPort = 5055; } ];
                volumeMounts = [
                  { mountPath = "/app/config"; name = "config"; }
                ];
              }
            ];
            volumes = [
              { name = "config"; persistentVolumeClaim.claimName = "seerr-config"; }
            ];
          };
        };
      };
    };

    seerr-pvc.content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "seerr-config";
        labels."app.kubernetes.io/name" = "seerr";
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        storageClassName = "local-path";
        resources.requests.storage = "500Mi";
      };
    };

    seerr-service.content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "seerr";
        labels."app.kubernetes.io/name" = "seerr";
      };
      spec = {
        selector."app.kubernetes.io/name" = "seerr";
        type = "ClusterIP";
        ports = [
          { name = "http"; protocol = "TCP"; port = 80; targetPort = 5055; }
        ];
      };
    };

    seerr-ingress.content = {
      apiVersion = "networking.k8s.io/v1";
      kind = "Ingress";
      metadata = {
        name = "seerr";
        labels."app.kubernetes.io/name" = "seerr";
        annotations."kubernetes.io/ingress.class" = "caddy";
      };
      spec = {
        ingressClassName = "caddy";
        rules = [
          {
            http.paths = [
              {
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "seerr";
                  port.number = 80;
                };
              }
            ];
          }
        ];
      };
    };
  };
}