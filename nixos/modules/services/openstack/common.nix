{ config, lib, pkgs }:
{ name, cfg, pkg }:

with lib;

{
  mkUwsgiService = name: port: requires:
    let
      uwsgiConfig.uwsgi = {
        type = "normal";
        plugins = [ "python3" ];
        wsgi-file = "${pkg}/bin/.${name}-wrapped";
        http = "localhost:${toString port}";
      };

      uwsgiConfigFile = pkgs.writeText "uwsgi-${name}.json" (builtins.toJSON uwsgiConfig);

    in
    {
      systemd.services."${name}" = {
        wantedBy = [ "multi-user.target" ];
        requires = requires;
        serviceConfig = {
          ExecStart = "${pkgs.coreutils}/bin/env -C $RUNTIME_DIRECTORY ${pkgs.uwsgi.override { plugins = ["python3"]; }}/bin/uwsgi --json ${uwsgiConfigFile}";
          User = cfg.user;
          Group = cfg.group;
          RuntimeDirectory = "uwsgi-${name}";
        };
      };
    };

  mkService = name: description: execStart: {
    systemd.services.${name} = {
      description = description;
      after = [ "syslog.target" "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "notify";
        NotifyAccess = "all";
        TimeoutStartSec = 0;
        Restart = "always";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = execStart;
      };
    };
  };

  mkCommonOptions = dbs: {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable openstack ${name} service.
      '';
    };

    user = mkOption {
      type = types.str;
      default = name;
      description = "User account under which ${name} will run.";
    };

    group = mkOption {
      type = types.str;
      default = name;
      description = "Group account under which ${name} will run.";
    };
  } // (optionalAttrs dbs {
    createDatabasesLocally = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Create the database and database user locally.
      '';
    };
  });

  mkDatabaseOptions = dbname: {
    databases.${dbname} = {
      dbtype = mkOption {
        type = types.enum [ "sqlite" "postgresql" "mysql" ];
        default = "postgresql";
        description = "Database type.";
      };

      dbname = mkOption {
        type = types.nullOr types.str;
        default = dbname;
        description = "Database name.";
      };

      dbuser = mkOption {
        type = types.nullOr types.str;
        default = name;
        description = "Database user.";
      };

      dbpass = mkOption {
        type = types.str;
        default = name;
        description = ''
          The full path to a file that contains the database password.
        '';
      };

      dbhost = mkOption {
        type = types.nullOr types.str;
        default = "localhost";
        description = ''
          Database host.

          Note: for using Unix authentication with PostgreSQL, this should be
          set to <literal>/run/postgresql</literal>.
        '';
      };

      dbport = mkOption {
        type = with types; str;
        default = "5432";
        description = "Database port.";
      };
    };
  };

  commonConfig = {
    services.postgresql = mkIf cfg.createDatabasesLocally {
      enable = true;
      enableTCPIP = true;

      authentication = mkOverride 10 ''
        local all all trust
        host all all 127.0.0.1/32 trust
        host all all ::1/128 trust
      '';

      ensureDatabases = map (db: db.dbname) (attrValues cfg.databases);
      ensureUsers = map
        (db: {
          name = db.dbuser;
          ensurePermissions."DATABASE ${db.dbname}" = "ALL PRIVILEGES";
        })
        (attrValues cfg.databases);
    };

    users.users = optionalAttrs (cfg.user == name) {
      ${name} = {
        group = cfg.group;
        uid = config.ids.uids.${name};
      };
    };

    users.groups = optionalAttrs (cfg.group == name) {
      ${name}.gid = config.ids.gids.${name};
    };
  };
}
