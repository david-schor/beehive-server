{ pkgs, config, vars, nixidyEnvs, ... }:

# bootstraping argocd to services.k3s with nixidy env vars
let
  target = nixidyEnvs.dev.config.nixidy.target;
in
{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable traefik"
      "--default-local-storage-path /data"
    ];

    autoDeployCharts.argocd = {
      name = "argo-cd";
      repo = "https://argoproj.github.io/argo-helm";
      version = vars.argocdVersion;
      hash = vars.argocdHash;
      targetNamespace = "argocd";
      createNamespace = true;

      values = {
        configs.params."server.insecure" = true;
      };
    };

    manifests = {
      "00-argocd-root-app".content = {
        apiVersion = "argoproj.io/v1alpha1";
        kind = "Application";
        metadata = {
          name = "root";
          namespace = "argocd";
        };
        spec = {
          project = "default";
          source = {
            repoURL = target.repository;
            targetRevision = target.branch;
            path = "${target.rootPath}/apps";
          };
          destination = {
            server = "https://kubernetes.default.svc";
            namespace = "argocd";
          };
          syncPolicy.automated = {
            prune = true;
            selfHeal = true;
          };
        };
      };
    };
  };
}