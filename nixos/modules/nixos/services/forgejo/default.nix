{ lib
, config
, pkgs
, ...
}:
with lib;
let
  cfg = config.mySystem.${category}.${app};
  app = "forgejo";
  category = "services";
  description = "A gitea fork with some extra features";
  #image = "codeberg.org/forgejo/forgejo:10.0.2-rootless";
  # Forgejo is a little different
  forgejo-user = "git";
  user = forgejo-user;
  group = forgejo-user;
  port = 3000; #int
  appFolder = "/var/lib/${app}";
  #persistentFolder = "${config.mySystem.persistentFolder}/var/lib/${appFolder}";
  host = "${app}" + (if cfg.dev then "-dev" else "");
  url = "${app}.${config.networking.domain}";
  new_url = "git.${config.networking.domain}";
  extra_url = "git.codewalker.dev";

in
{
  options.mySystem.${category}.${app} =
    {
      enable = mkEnableOption "${app}";
      user = forgejo-user;
      group = forgejo-user;
      addToHomepage = mkEnableOption "Add ${app} to homepage" // { default = true; };
      monitor = mkOption
        {
          type = lib.types.bool;
          description = "Enable gatus monitoring";
          default = true;
        };
      prometheus = mkOption
        {
          type = lib.types.bool;
          description = "Enable prometheus scraping";
          default = true;
        };
      addToDNS = mkOption
        {
          type = lib.types.bool;
          description = "Add to DNS list";
          default = true;
        };
      dev = mkOption
        {
          type = lib.types.bool;
          description = "Development instance";
          default = false;
        };
      backup = mkOption
        {
          type = lib.types.bool;
          description = "Enable backups";
          default = true;
        };



    };

  config = mkIf cfg.enable {

    ## Secrets
    # sops.secrets."${category}/${app}/env" = {
    #   sopsFile = ./secrets.sops.yaml;
    #   owner = user;
    #   group = group;
    #   restartUnits = [ "${app}.service" ];
    # };

    users.users.${forgejo-user} = {
      home = config.services.forgejo.stateDir;
      useDefaultShell = true;
      group = forgejo-user;
      isSystemUser = true;
    };

    users.groups.${forgejo-user} = { };

    # Folder perms - only for containers
    systemd.tmpfiles.rules = [
      "d ${appFolder}/ 0750 ${user} ${group} -"
    ];

    environment.persistence."${config.mySystem.system.impermanence.persistPath}" = lib.mkIf config.mySystem.system.impermanence.enable {
      directories = [{ directory = appFolder; inherit user; inherit group; mode = "750"; }];
    };

    services.forgejo = {
      package = pkgs.unstable.forgejo; # TODO: Switch back to stable once v8 becomes stable

      enable = true;
      user = forgejo-user;
      group = forgejo-user;

      stateDir = "${appFolder}";
      database.type = "sqlite3";
      # Enable support for Git Large File Storage
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = "${new_url}";
          ROOT_URL = "https://${new_url}/";
          HTTP_PORT = port;
          MINIMUM_KEY_SIZE_CHECK = false;
          #SSH_PORT = head config.services.openssh.ports;
        };
        service = {
          DISABLE_REGISTRATION = true;
          DEFAULT_KEEP_EMAIL_PRIVATE = false;
          DEFAULT_ALLOW_CREATE_ORGANIZATION = true;
          DEFAULT_ENABLE_TIMETRACKING = true;
          NO_REPLY_ADDRESS = "noreply.${app}.${config.networking.domain}";
        };
        # Add support for actions, based on act: https://github.com/nektos/act
        actions = {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "github";
        };
        # Disable mailer
        mailer = {
          ENABLED = false;
        };
        # Allow OpenID signups
        openid = {
          ENABLE_OPENID_SIGNIN = true;
          ENABLE_OPENID_SIGNUP = true;
        };
        webhook = {
          ALLOWED_HOST_LIST = "private,*.${config.networking.domain}";
        };
      };
    };

    # # homepage integration
    # mySystem.services.homepage.infrastructure = mkIf cfg.addToHomepage [
    #   {
    #     ${app} = {
    #       icon = "${app}.svg";
    #       href = "https://${url}";
    #       inherit description;
    #     };
    #   }
    # ];

    ### gatus integration
    mySystem.services.gatus.monitors = mkIf cfg.monitor [
      {
        name = app;
        group = "${category}";
        url = "https://${new_url}";
        interval = "1m";
        ui = {
          hide-hostname = true;
          hide-url = true;
        };
        conditions = [ "[CONNECTED] == true" "[STATUS] == 200" "[RESPONSE_TIME] < 50" ];
      }
    ];

    ### Ingress
    services.nginx.virtualHosts.${new_url} = {
      forceSSL = true;
      useACMEHost = config.networking.domain;
      locations."^~ /" = {
        proxyPass = "http://127.0.0.1:${builtins.toString port}";
        extraConfig = "resolver 10.88.0.1;";
      };
    };
    services.nginx.virtualHosts.${extra_url} = {
      forceSSL = true;
      useACMEHost = "codewalker.dev";
      locations."^~ /" = {
        proxyPass = "http://127.0.0.1:${builtins.toString port}";
        extraConfig = "resolver 10.88.0.1;";
      };
    };
    ### Redirect for old hostname
    services.nginx.virtualHosts.${url} = {
      forceSSL = true;
      useACMEHost = config.networking.domain;
      globalRedirect = "${new_url}";
    };

    ### firewall config

    # networking.firewall = mkIf cfg.openFirewall {
    #   allowedTCPPorts = [ port ];
    #   allowedUDPPorts = [ port ];
    # };

    ### backups
    warnings = [
      (mkIf (!cfg.backup && config.mySystem.purpose != "Development")
        "WARNING: Backups for ${app} are disabled!")
    ];

    services.restic.backups = mkIf cfg.backup (config.lib.mySystem.mkRestic
      {
        inherit app user;
        paths = [ appFolder ];
        inherit appFolder;
      });


    # services.postgresqlBackup = {
    #   databases = [ app ];
    # };



  };
}
