{ config, lib, pkgs, ... }:

with lib;

let
  name = "keystone";
  cfg = config.services.openstack.${name};
  pkg = pkgs.openstackPkgs.keystone;

  common = (import ./common.nix {
    inherit config lib pkgs;
  }) {
    inherit name cfg pkg;
  };

in
{
  options.services.openstack.keystone = (foldr recursiveUpdate { } [
    (common.mkCommonOptions true)
    (common.mkDatabaseOptions "keystone")
    {
      password = mkOption {
        type = types.str;
        default = "keystone";
        description = ''
          	  The keystone bootstrap admin password
        '';
      };
    }
  ]);

  config = mkIf cfg.enable (foldr recursiveUpdate { } [{
    systemd.services.keystone-init = {
      wantedBy = [ "uwsgi.service" ];
      serviceConfig = {
        User = "root";
        Group = "root";
        Type = "oneshot";
        ExecStart = pkgs.writeScript "keystone-init" ''
          #!${pkgs.bash}/bin/sh

          /run/wrappers/bin/su -s ${pkgs.bash}/bin/sh -c "${pkg}/bin/keystone-manage db_sync" ${cfg.user}

          ${pkg}/bin/keystone-manage fernet_setup --keystone-user ${cfg.user} --keystone-group ${cfg.group}
          ${pkg}/bin/keystone-manage credential_setup --keystone-user ${cfg.user} --keystone-group ${cfg.group}

          ${pkg}/bin/keystone-manage bootstrap --bootstrap-password "${cfg.password}" \
              --bootstrap-admin-url http://localhost:35357/v3/ \
              --bootstrap-internal-url http://localhost:5000/v3/ \
              --bootstrap-public-url http://localhost:5000/v3/ \
              --bootstrap-region-id RegionOne
        '';
      };
    };

    environment.etc."keystone/keystone.conf".text = with cfg.databases.keystone; ''
      [database]
      connection = ${dbtype}://${dbuser}:${dbpass}@${dbhost}:${dbport}/${dbname}

      [token]
      provider = fernet
    '';
  }
    common.commonConfig
    (common.mkUwsgiService "keystone-wsgi-public" 5001 [ "keystone-init.service" ])
    (common.mkUwsgiService "keystone-wsgi-admin" 35357 [ "keystone-init.service" ])]);
}
