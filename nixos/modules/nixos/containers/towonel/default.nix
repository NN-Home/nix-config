{ lib
, config
, pkgs
, ...
}:
with lib;
let
  app = "towonel";
  image = "codeberg.org/towonel/towonel-agent:1.0.1@sha256:bdd7d6cb166bf2f985ebc98b03c866c65300aa0432f0a43b2fe44c3e8e5dad44";
  user = "568"; #string
  group = "568"; #string
  #port = 9898; #int
  cfg = config.mySystem.services.${app};
  appFolder = "/var/lib/${app}";
  # persistentFolder = "${config.mySystem.persistentFolder}/var/lib/${appFolder}";
in
{
  options.mySystem.services.${app} =
    {
      enable = mkEnableOption "${app}";
      addToHomepage = mkEnableOption "Add ${app} to homepage" // { default = true; };
    };

  config = mkIf cfg.enable {
    sops.secrets."services/${app}/env" = {
      sopsFile = ./secrets.sops.yaml;
      owner = config.users.users.kah.name;
      inherit (config.users.users.kah) group;
      restartUnits = [ "podman-${app}.service" ];
    };

    virtualisation.oci-containers.containers.${app} = {
      image = "${image}";
      user = "${user}:${group}";
      environmentFiles = [ config.sops.secrets."services/${app}/env".path ];
      extraOptions = [ "--network" "host" ];
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
      ];

    };

    services.vmagent = {
      prometheusConfig = {
        scrape_configs = [
          {
            job_name = "towonel";
            # scrape_timeout = "40s";
            static_configs = [
              {
                targets = [ "http://127.0.0.1:9090" ];
                labels.instance = "${config.networking.hostName}";
              }
            ];
          }
        ];
      };
    };


  };
}
