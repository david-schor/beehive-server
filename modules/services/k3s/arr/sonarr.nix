{ pkgs, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/hotio/sonarr";
    imageDigest = "sha256:67e97fff243bcbac298c7fbfeae7cbda50790846ec7e1b493ae2d02867128010"; 
    hash = "sha256-dIBcsi6bpWch760t71tra6lX/UiucPa7quzXqjUQQIQ=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  services.k3s.images = [ image ];

  services.k3s.manifests = {
    sonarr-deployment.content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "sonarr";
        labels."app.kubernetes.io/name" = "sonarr";
      };
      spec = {
        replicas = 1;
        selector.matchLabels."app.kubernetes.io/name" = "sonarr";
        template = {
          metadata.labels."app.kubernetes.io/name" = "sonarr";
          spec = {
            containers = [
              {
                name = "sonarr";
                image = "${image.imageName}:${image.imageTag}";
                env = [
                  { name = "PUID"; value = "1000"; }
                  { name = "PGID"; value = "1000"; }
                  { name = "TZ";   value = "Europe/Zurich"; }
                ];
                ports = [ { containerPort = 8989; } ];
                volumeMounts = [
                  { mountPath = "/config";  name = "config"; }
                  { mountPath = "/data";    name = "data"; }
                ];
              }
            ];
            volumes = [
              { name = "config"; persistentVolumeClaim.claimName = "sonarr-config"; }
              { name = "data";   hostPath.path = "/data/arr"; }
            ];
          };
        };
      };
    };

    sonarr-pvc.content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "sonarr-config";
        labels."app.kubernetes.io/name" = "sonarr";
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        storageClassName = "local-path";
        resources.requests.storage = "500Mi";
      };
    };

    sonarr-service.content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "sonarr";
        labels."app.kubernetes.io/name" = "sonarr";
      };
      spec = {
        selector."app.kubernetes.io/name" = "sonarr";
        type = "ClusterIP";
        ports = [
          { name = "http"; protocol = "TCP"; port = 80; targetPort = 8989; }
        ];
      };
    };

    sonarr-ingress.content = {
      apiVersion = "networking.k8s.io/v1";
      kind = "Ingress";
      metadata = {
        name = "sonarr";
        labels."app.kubernetes.io/name" = "sonarr";
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
                  name = "sonarr";
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