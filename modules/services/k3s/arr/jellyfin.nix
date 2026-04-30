{ pkgs, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "jellyfin/jellyfin";
    imageDigest = "sha256:1694ff069f0c9dafb283c36765175606866769f5d72f2ed56b6a0f1be922fc37"; 
    hash = "sha256-0drc5RMB/GfW3fU130WTyAB4a8AfPBHMXNghFDwYPPs=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  services.k3s.images = [ image ];

  services.k3s.manifests = {
    jellyfin-deployment.content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "jellyfin";
        labels."app.kubernetes.io/name" = "jellyfin";
      };
      spec = {
        replicas = 1;
        selector.matchLabels."app.kubernetes.io/name" = "jellyfin";
        template = {
          metadata.labels."app.kubernetes.io/name" = "jellyfin";
          spec = {
            containers = [
              {
                name = "jellyfin";
                image = "${image.imageName}:${image.imageTag}";
                env = [
                  { name = "TZ"; value = "Europe/Zurich"; }
                ];
                ports = [ { containerPort = 8096; } ];
                volumeMounts = [
                  { mountPath = "/config";  name = "config"; }
                  { mountPath = "/cache";   name = "cache"; }
                  { mountPath = "/data";    name = "data"; }
                ];
                # resources.limits."gpu.intel.com/i915" = 1;
              }
            ];
            volumes = [
              { name = "config"; persistentVolumeClaim.claimName = "jellyfin-config"; }
              { name = "cache";  persistentVolumeClaim.claimName = "jellyfin-cache"; }
              { name = "data";   hostPath.path = "/data/arr"; }
            ];
          };
        };
      };
    };

    jellyfin-pvc-config.content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "jellyfin-config";
        labels."app.kubernetes.io/name" = "jellyfin";
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        storageClassName = "local-path";
        resources.requests.storage = "1Gi";
      };
    };

    jellyfin-pvc-cache.content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "jellyfin-cache";
        labels."app.kubernetes.io/name" = "jellyfin";
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        storageClassName = "local-path";
        resources.requests.storage = "5Gi";
      };
    };

    jellyfin-service.content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "jellyfin";
        labels."app.kubernetes.io/name" = "jellyfin";
      };
      spec = {
        selector."app.kubernetes.io/name" = "jellyfin";
        type = "ClusterIP";
        ports = [
          { name = "http"; protocol = "TCP"; port = 80; targetPort = 8096; }
        ];
      };
    };

    jellyfin-ingress.content = {
      apiVersion = "networking.k8s.io/v1";
      kind = "Ingress";
      metadata = {
        name = "jellyfin";
        labels."app.kubernetes.io/name" = "jellyfin";
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
                  name = "jellyfin";
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
