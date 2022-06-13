{ config, lib, pkgs, ... }:

with lib;

let
  name = "nova";
  cfg = config.services.openstack.nova-controller;
  pkg = pkgs.openstackPkgs.nova;

  common = (import ./common.nix {
    inherit config lib pkgs;
  }) {
    inherit name cfg pkg;
  };

in
{
  options.services.openstack.nova-controller = (foldr recursiveUpdate { } [
    (common.mkCommonOptions true)
    (common.mkDatabaseOptions "nova")
    (common.mkDatabaseOptions "nova_api")
    (common.mkDatabaseOptions "nova_cell0")
    {
      password = mkOption {
        type = types.str;
        default = "nova";
        description = ''
          	  The nova service password
        '';
      };
    }
  ]);

  config = mkIf cfg.enable (foldr recursiveUpdate { } [{
    systemd.services.nova-controller-init = {
      wantedBy = [ "uwsgi.service" ];
      serviceConfig = {
        User = "root";
        Group = "root";
        Type = "oneshot";
        ExecStart = pkgs.writeScript "nova-controller-init" ''
          #!${pkgs.bash}/bin/sh
        '';
      };
    };

    environment.etc."nova/nova.conf".text = ''
      [DEFAULT]
      enabled_apis = osapi_compute,metadata
    '' + (with cfg.databases.nova; ''
      [database]
      connection = ${dbtype}://${dbuser}:${dbpass}@${dbhost}:${dbport}/${dbname}
    '') + (with cfg.databases.nova_api; ''
      [api_database]
      connection = ${dbtype}://${dbuser}:${dbpass}@${dbhost}:${dbport}/${dbname}
    '') + ''
      [api]
      auth_strategy = keystone

      [keystone_authtoken]
      www_authenticate_uri = http://localhost:5000/
      auth_url = http://localhost:5000/
      memcached_servers = localhost:11211
      auth_type = password
      project_domain_name = Default
      user_domain_name = Default
      project_name = service
      username = nova
      password = ${cfg.password}
    '';
  }
    common.commonConfig
    (common.mkService "nova-conductor" "OpenStack Nova Conductor Server" "${pkg}/bin/nova-conductor")
    (common.mkService "nova-api" "OpenStack Nova API Server" "${pkg}/bin/nova-api")
    (common.mkService "nova-scheduler" "OpenStack Nova Scheduler Server" "${pkg}/bin/nova-scheduler")]);
}
