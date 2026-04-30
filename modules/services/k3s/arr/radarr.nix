{ pkgs, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/hotio/radarr";
    imageDigest = "sha256:a0378fd5be0d23e23eea5f183e12619d2c1d74f70e5dc4a124c315343595f2ae"; 
    hash = "sha256-VCU4yB5tFljhec28BB+IynwOCHEAoBzW9OXiAjRhLys=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  services.k3s.images = [ image ];

  services.k3s.manifests = {
    radarr-deployment.content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "radarr";
        labels."app.kubernetes.io/name" = "radarr";
      };
      spec = {
        replicas = 1;
        selector.matchLabels."app.kubernetes.io/name" = "radarr";
        template = {
          metadata.labels."app.kubernetes.io/name" = "radarr";
          spec = {
            containers = [
              {
                name = "radarr";
                image = "${image.imageName}:${image.imageTag}";
                env = [
                  { name = "PUID"; value = "1000"; }
                  { name = "PGID"; value = "1000"; }
                  { name = "TZ";   value = "Europe/Zurich"; }
                ];
                ports = [ { containerPort = 7878; } ];
                volumeMounts = [
                  { mountPath = "/config"; name = "config"; }
                  { mountPath = "/data";   name = "data"; }
                ];
              }
            ];
            volumes = [
              { name = "config"; persistentVolumeClaim.claimName = "radarr-config"; }
              { name = "data";   hostPath.path = "/data/arr"; }
            ];
          };
        };
      };
    };

    radarr-pvc.content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "radarr-config";
        labels."app.kubernetes.io/name" = "radarr";
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        storageClassName = "local-path";
        resources.requests.storage = "500Mi";
      };
    };

    radarr-service.content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "radarr";
        labels."app.kubernetes.io/name" = "radarr";
      };
      spec = {
        selector."app.kubernetes.io/name" = "radarr";
        type = "ClusterIP";
        ports = [
          { name = "http"; protocol = "TCP"; port = 80; targetPort = 7878; }
        ];
      };
    };

    radarr-ingress.content = {
      apiVersion = "networking.k8s.io/v1";
      kind = "Ingress";
      metadata = {
        name = "radarr";
        labels."app.kubernetes.io/name" = "radarr";
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
                  name = "radarr";
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