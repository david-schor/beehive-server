{ pkgs, config, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "docker.io/prom/prometheus";
    imageDigest = "sha256:5ce7540c3c00ef4ab0c9d2c995c6a5b9c421f44b4a115d97a2c7af3b1c21cbb0";
    hash = "sha256-FiRygVk9FRRKsHA4kpkiDre2ORLYI7CSkV7+odUcBSw=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  services.k3s = {
    images = [ image ];
    manifests = {
      prometheus-cluster-role.content = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRole";
        metadata = {
          name = "prometheus";
          labels."app.kubernetes.io/name" = "prometheus";
        };
        rules = [
          {
            apiGroups = [ "" ];
            resources = [
              "nodes"
              "nodes/proxy"
              "services"
              "endpoints"
              "pods"
            ];
            verbs = [
              "get"
              "list"
              "watch"
            ];
          }
          {
            apiGroups = [ "extensions" ];
            resources = [ "ingresses" ];
            verbs = [
              "get"
              "list"
              "watch"
            ];
          }
          {
            nonResourceURLs = [ "/metrics" ];
            verbs = [ "get" ];
          }
        ];
      };
      prometheus-cluster-role-binding.content = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRoleBinding";
        metadata = {
          name = "prometheus";
          labels."app.kubernetes.io/name" = "prometheus";
        };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "prometheus";
        };
        subjects = [
          {
            kind = "ServiceAccount";
            name = "prometheus";
            namespace = "default";
          }
        ];
      };
      prometheus-serviceaccount.content = {
        apiVersion = "v1";
        kind = "ServiceAccount";
        metadata = {
          name = "prometheus";
          labels."app.kubernetes.io/name" = "prometheus";
        };
      };
      prometheus-config-map.content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "prometheus-server-conf";
          labels."app.kubernetes.io/name" = "prometheus";
        };
        data."prometheus.yaml" = builtins.readFile ./prometheus.yaml;
      };
      prometheus-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "prometheus";
          labels."app.kubernetes.io/name" = "prometheus";
        };
        spec = {
          replicas = 1;
          selector.matchLabels."app.kubernetes.io/name" = "prometheus";
          template = {
            metadata.labels."app.kubernetes.io/name" = "prometheus";
            spec = {
              containers = [
                {
                  name = "prometheus";
                  image = "${image.imageName}:${image.imageTag}";
                  args = [
                    "--config.file=/etc/prometheus/prometheus.yaml"
                    "--storage.tsdb.path=/prometheus/"
                  ];
                  ports = [ { containerPort = 9090; } ];
                  volumeMounts = [
                    {
                      mountPath = "/prometheus";
                      name = "storage";
                    }
                    {
                      mountPath = "/etc/prometheus";
                      name = "config";
                      readOnly = true;
                    }
                  ];
                }
              ];
              serviceAccountName = "prometheus";
              volumes = [
                {
                  name = "storage";
                  persistentVolumeClaim.claimName = "prometheus";
                }
                {
                  name = "config";
                  configMap.name = "prometheus-server-conf";
                }
              ];
            };
          };
        };
      };
      prometheus-pvc.content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "prometheus";
          labels."app.kubernetes.io/name" = "prometheus";
        };
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          storageClassName = "local-path";
          resources.requests.storage = "5Gi";
        };
      };
      prometheus-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "prometheus";
          labels."app.kubernetes.io/name" = "prometheus";
        };
        spec = {
          selector."app.kubernetes.io/name" = "prometheus";
          ports = [
            {
              name = "http";
              protocol = "TCP";
              port = 80;
              targetPort = 9090;
            }
          ];
        };
      };
    };
  };
}