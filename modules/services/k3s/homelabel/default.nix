{ pkgs, config, ... }:

let
    backendImage = pkgs.dockerTools.pullImage {
        imageName = "ghcr.io/pouzor/homelable-backend";
        imageDigest = "sha256:504b7565da91ef7c3968f626d2a1f4e98746d1ca2e852a4782cd696bcdff8870";     
        hash = "sha256-785pWMMm4T5vejTxcuD30/T8eYJwSmKIBR+Z5GdiaRQ=";
        finalImageName = "ghcr.io/pouzor/homelable-backend";
        finalImageTag = "latest";
    };

    frontendImage = pkgs.dockerTools.pullImage {
        imageName = "ghcr.io/pouzor/homelable-frontend";
        imageDigest = "sha256:8f72b654bb02fb792c1ae9c376b36c80d628ca4bcdf770e9440dc0d83da4f351";
        hash = "sha256-eZ2+FYVO8aYfT0T9z23vaNYF/Nv4q2aF8pkpv4evi/c=";
        finalImageName = "ghcr.io/pouzor/homelable-frontend";
        finalImageTag = "latest";
  };
in
{
    sops.templates.homelabel-k3s-secret = {
        path = "/var/lib/rancher/k3s/server/manifests/homelabel-secret.yaml";
        content = builtins.toJSON {
            apiVersion = "v1";
            kind = "Secret";
            metadata.name = "homelabel-secrets";
            type = "Opaque";
            stringData = {
                admin-token = config.sops.placeholder."homelabel-password";
            };
        };
    };

    services.k3s = {
    images = [ backendImage frontendImage ];
    manifests = {
      homelable-backend-pvc.content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "homelable-backend";
          labels."app.kubernetes.io/name" = "homelable-backend";
        };
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          storageClassName = "local-path";
          resources.requests.storage = "2Gi";
        };
      };

      homelable-backend-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "homelable-backend";
          labels."app.kubernetes.io/name" = "homelable-backend";
        };
        spec = {
          replicas = 1;
          selector.matchLabels."app.kubernetes.io/name" = "homelable-backend";
          template = {
            metadata.labels."app.kubernetes.io/name" = "homelable-backend";
            spec = {
              containers = [
                {
                  name = "backend";
                  image = "${backendImage.imageName}:${backendImage.imageTag}";
                  env = [
                    {
                      name = "AUTH_USERNAME";
                      value = "admin";
                    }
                    {
                      name = "AUTH_PASSWORD_HASH";
                      valueFrom.secretKeyRef = {
                        name = "homelable-secrets";
                        key = "admin-token";
                      };
                    }
                    {
                      name = "SQLITE_PATH";
                      value = "/app/data/homelab.db";
                    }
                  ];
                  securityContext.capabilities.add = [ "NET_RAW" ];
                  ports = [ { containerPort = 8000; } ];
                  volumeMounts = [
                    {
                      mountPath = "/app/data";
                      name = "storage";
                    }
                  ];
                  livenessProbe = {
                    httpGet = {
                      path = "/api/v1/health";
                      port = 8000;
                    };
                    timeoutSeconds = 30;
                    failureThreshold = 1;
                  };
                  startupProbe = {
                    httpGet = {
                      path = "/api/v1/health";
                      port = 8000;
                    };
                    timeoutSeconds = 30;
                    failureThreshold = 10;
                  };
                  readinessProbe.httpGet = {
                    path = "/api/v1/health";
                    port = 8000;
                  };
                }
              ];
              volumes = [
                {
                  name = "storage";
                  persistentVolumeClaim.claimName = "homelable-backend";
                }
              ];
            };
          };
        };
      };

      homelable-backend-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "backend";
          labels."app.kubernetes.io/name" = "homelable-backend";
        };
        spec = {
          selector."app.kubernetes.io/name" = "homelable-backend";
          ports = [
            {
              port = 8000;
              targetPort = 8000;
            }
          ];
        };
      };

      homelable-frontend-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "homelable-frontend";
          labels."app.kubernetes.io/name" = "homelable-frontend";
        };
        spec = {
          replicas = 1;
          selector.matchLabels."app.kubernetes.io/name" = "homelable-frontend";
          template = {
            metadata.labels."app.kubernetes.io/name" = "homelable-frontend";
            spec = {
              containers = [
                {
                  name = "frontend";
                  image = "${frontendImage.imageName}:${frontendImage.imageTag}";
                  ports = [ { containerPort = 80; } ];
                }
              ];
            };
          };
        };
      };

      homelable-frontend-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "frontend";
          labels."app.kubernetes.io/name" = "homelable-frontend";
        };
        spec = {
          selector."app.kubernetes.io/name" = "homelable-frontend";
          ports = [
            {
              port = 80;
              targetPort = 80;
            }
          ];
        };
      };

      homelable-ingress.content = {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "homelable";
          labels."app.kubernetes.io/name" = "homelable";
        };
        spec = {
          ingressClassName = "caddy";
          rules = [
            {
              host = "homelable.local";
              http.paths = [
                {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    name = "frontend";
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
