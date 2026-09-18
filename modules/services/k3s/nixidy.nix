{ vars, ... }:

{
  nixidy.target.repository = vars.gitRepo;
  nixidy.target.branch = "main";
  nixidy.target.rootPath = "./manifests";
}