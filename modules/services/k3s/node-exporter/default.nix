{ pkgs, ... }:

let
  image = pkgs.dockerTools.pullImage {
    imageName = "docker.io/prom/node-exporter";
    imageDigest = "sha256:1b4e4438faca4dd7e001dd445d161a4a2091b0fededa84093b3a8dfeae1f1be0";
    hash = "sha256-Us01w7MzoSLV6441UT+TqTZ7pyZubg1KpTi/qfXFQ/o=";
    finalImageTag = "latest";
    arch = "amd64";
  };
in
{
  services.k3s = {
    images = [ image ];
    manifests = {
      node-exporter-daemonset.content = {
        apiVersion = "apps/v1";
        kind = "DaemonSet";
        metadata = {
          name = "node-exporter";
          labels."app.kubernetes.io/name" = "node-exporter";
        };
        spec = {
          selector.matchLabels."app.kubernetes.io/name" = "node-exporter";
          template = {
            metadata.labels."app.kubernetes.io/name" = "node-exporter";
            spec = {
              containers = [
                {
                  name = "node-exporter";
                  image = "${image.imageName}:${image.imageTag}";
                  args = [
                    "--path.sysfs=/host/sys"
                    "--path.rootfs=/host/root"
                    "--no-collector.wifi"
                    "--no-collector.hwmon"
                    "--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)"
                    "--collector.netclass.ignored-devices=^(veth.*)$"
                  ];
                  ports = [ { containerPort = 9100; } ];
                  volumeMounts = [
                    {
                      mountPath = "/host/sys";
                      mountPropagation = "HostToContainer";
                      name = "sys";
                      readOnly = true;
                    }
                    {
                      mountPath = "/host/root";
                      mountPropagation = "HostToContainer";
                      name = "root";
                      readOnly = true;
                    }
                  ];
                }
              ];
              hostNetwork = true;
              volumes = [
                {
                  hostPath.path = "/sys";
                  name = "sys";
                }
                {
                  hostPath.path = "/";
                  name = "root";
                }
              ];
            };
          };
        };
      };
      node-exporter-service.content = {
        kind = "Service";
        apiVersion = "v1";
        metadata.name = "node-exporter";
        spec = {
          selector."app.kubernetes.io/name" = "node-exporter";
          ports = [
            {
              name = "node-exporter";
              protocol = "TCP";
              port = 9100;
              targetPort = 9100;
            }
          ];
        };
      };
    };
  };
}