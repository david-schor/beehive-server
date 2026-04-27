{ pkgs, config, ... }:

let
  caddyPlugins = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/infomaniak@v1.0.2"
    ];
    hash = "sha256-dL6TI4hZP4nYj2iTXConqhVm4ep/Z5YiiRfF8fRp/mo=";
  };

  caddyImageName = "caddy";
  caddyImageTag  = "infomaniak-${builtins.substring 0 8 (builtins.hashString "sha256" caddyPlugins.outPath)}";

  image = pkgs.dockerTools.buildLayeredImage {
    name = caddyImageName;
    tag  = caddyImageTag;
    contents = [ caddyPlugins ];
    config = {
      Entrypoint = [ "${caddyPlugins}/bin/caddy" ];
      Cmd        = [ "run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile" ];
      ExposedPorts = { "80/tcp" = {}; "443/tcp" = {}; };
      Env = [ "XDG_DATA_HOME=/data" "XDG_CONFIG_HOME=/config" ];
    };
  };

in
{
  services.k3s.images = [ image ];

  systemd.services.k3s.serviceConfig.ExecStartPre = [
    "${pkgs.bash}/bin/bash -c 'rm -f /var/lib/rancher/k3s/server/manifests/caddy-deployment.yaml'"
    "${pkgs.bash}/bin/bash -c 'rm -f /var/lib/rancher/k3s/server/manifests/caddy-config-map.yaml'"
  ];

  systemd.services.k3s-import-caddy = {
    description = "Import caddy image into k3s";
    after = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.k3s}/bin/k3s ctr images import ${image}";
    };
  };

  sops.templates.caddy-k3s-secret = {
    path = "/var/lib/rancher/k3s/server/manifests/caddy-secret.yaml";
    content = builtins.toJSON {
      apiVersion = "v1";
      kind = "Secret";
      metadata.name = "caddy-secrets";
      type = "Opaque";
      stringData = {
        infomaniak-api-token = config.sops.placeholder."infomaniak-api-token";
      };
    };
  };

  services.k3s.manifests = {
    caddy-config-map.content = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "caddy-config";
        labels."app.kubernetes.io/name" = "caddy";
      };
      data.Caddyfile = builtins.readFile ./Caddyfile;
    };

    caddy-deployment.content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "caddy";
        labels."app.kubernetes.io/name" = "caddy";
      };
      spec = {
        replicas = 1;
        selector.matchLabels."app.kubernetes.io/name" = "caddy";
        template = {
          metadata.labels."app.kubernetes.io/name" = "caddy";
          spec = {
            containers = [
              {
                name  = "caddy";
                image = "${caddyImageName}:${caddyImageTag}";
                imagePullPolicy = "Never";
                env = [
                  {
                    name = "INFOMANIAK_API_TOKEN";
                    valueFrom.secretKeyRef = {
                      name = "caddy-secrets";
                      key  = "infomaniak-api-token";
                    };
                  }
                ];
                ports = [
                  { containerPort = 80; }
                  { containerPort = 443; }
                ];
                volumeMounts = [
                  { mountPath = "/etc/caddy/Caddyfile"; name = "config"; subPath = "Caddyfile"; readOnly = true; }
                  { mountPath = "/data";   name = "data"; }
                  { mountPath = "/config"; name = "caddy-config-cache"; }
                ];
              }
            ];
            volumes = [
              { name = "config"; configMap.name = "caddy-config"; }
              { name = "data";   persistentVolumeClaim.claimName = "caddy-data"; }
              { name = "caddy-config-cache"; emptyDir = {}; }
            ];
          };
        };
      };
    };

    caddy-pvc-data.content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "caddy-data";
        labels."app.kubernetes.io/name" = "caddy";
      };
      spec = {
        accessModes    = [ "ReadWriteOnce" ];
        storageClassName = "local-path";
        resources.requests.storage = "256Mi";
      };
    };

    caddy-service.content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "caddy";
        labels."app.kubernetes.io/name" = "caddy";
      };
      spec = {
        selector."app.kubernetes.io/name" = "caddy";
        type = "LoadBalancer";
        ports = [
          { name = "http";  protocol = "TCP"; port = 80;  targetPort = 80; }
          { name = "https"; protocol = "TCP"; port = 443; targetPort = 443; }
        ];
      };
    };
  };
}