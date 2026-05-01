{ pkgs, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "linuxserver/sabnzbd";
    imageDigest = "sha256:374051b90f64d107f8658dcd9b9065c28826afe14562647214f45057e119fc04";
    hash = "sha256-GEZoUkdkdEms/cNrop1wwK7zeh5N+XGKPnyAsmU5row=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  services.k3s.images = [ image ];

  services.k3s.manifests = {
    sabnzbd-deployment.content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "sabnzbd";
        labels."app.kubernetes.io/name" = "sabnzbd";
      };
      spec = {
        replicas = 1;
        selector.matchLabels."app.kubernetes.io/name" = "sabnzbd";
        template = {
          metadata.labels."app.kubernetes.io/name" = "sabnzbd";
          spec = {
            containers = [
              {
                name = "sabnzbd";
                image = "${image.imageName}:${image.imageTag}";
                env = [
                  { name = "PUID"; value = "1000"; }
                  { name = "PGID"; value = "1000"; }
                  { name = "TZ";   value = "Europe/Zurich"; }
                  { name = "SABNZBD__MISC__HOST_WHITELIST_ENTRIES"; value = "sabnzbd.schor.me, sabnzbd"; }
                  { name = "SABNZBD__MISC__COMPLETE_DIR";   value = "/data/usenet/complete"; }
                  { name = "SABNZBD__MISC__INCOMPLETE_DIR"; value = "/data/usenet/incomplete"; }
                 ];
                ports = [ { containerPort = 8080; } ];
                volumeMounts = [
                  { mountPath = "/config";              name = "config"; }
                  { mountPath = "/data";                name = "data"; }
                ];
              }
            ];    
            volumes = [
              { name = "config"; persistentVolumeClaim.claimName = "sabnzbd-config"; }
              { name = "data";   hostPath.path = "/data/arr"; }
            ];
          };
        };
      };
    };

    sabnzbd-pvc.content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "sabnzbd-config";
        labels."app.kubernetes.io/name" = "sabnzbd";
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        storageClassName = "local-path";
        resources.requests.storage = "500Mi";
      };
    };

    sabnzbd-service.content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "sabnzbd";
        labels."app.kubernetes.io/name" = "sabnzbd";
      };
      spec = {
        selector."app.kubernetes.io/name" = "sabnzbd";
        type = "ClusterIP";
        ports = [
          { name = "http"; protocol = "TCP"; port = 80; targetPort = 8080; }
        ];
      };
    };

    sabnzbd-ingress.content = {
      apiVersion = "networking.k8s.io/v1";
      kind = "Ingress";
      metadata = {
        name = "sabnzbd";
        labels."app.kubernetes.io/name" = "sabnzbd";
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
                  name = "sabnzbd";
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