{ config, lib, ... }:
let
  cfg = config.routeros.dns;
  connCfg = config.routeros.connection;
  hosts = config.routeros.hosts;
  helpers = config.routeros._lib;

  primaryRecords = lib.filterAttrs (_: host: host.dns) hosts;

  aliasEntries = lib.concatLists (
    lib.mapAttrsToList (
      _: host:
      builtins.map (alias: {
        name = alias;
        inherit (host) ip;
      }) host.aliases
    ) hosts
  );
in
{
  options.routeros.dns = {
    enable = lib.mkEnableOption "DNS configuration";

    upstream = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "8.8.8.8"
        "4.4.4.4"
      ];
      description = "Upstream DNS servers.";
    };

    localDomain = lib.mkOption {
      type = lib.types.str;
      default = "local";
      description = "Local domain for host DNS records (e.g. server.local).";
    };

    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional DNS aliases. Keys are DNS names, values are target host names from routeros.hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_dns.settings = {
        allow_remote_requests = true;
        servers = cfg.upstream;
      };

      routeros_ip_dns_record =
        # FWD rule for *.local — RouterOS regex escaping handled here
        {
          local_fwd = {
            forward_to = connCfg.gateway;
            regexp = ".*\\\\.${cfg.localDomain}$$";
            type = "FWD";
          };
        }
        # A records from hosts with dns=true
        // builtins.listToAttrs (
          lib.mapAttrsToList (name: host: {
            name = helpers.sanitizeName name;
            value = {
              address = host.ip;
              name = "${name}.${cfg.localDomain}";
              type = "A";
            };
          }) primaryRecords
        )
        # A records from host aliases
        // builtins.listToAttrs (
          builtins.map (entry: {
            name = "alias_${helpers.sanitizeName entry.name}";
            value = {
              address = entry.ip;
              name = "${entry.name}.${cfg.localDomain}";
              type = "A";
            };
          }) aliasEntries
        )
        # A records from dns.aliases (name -> target host from routeros.hosts)
        // builtins.listToAttrs (
          lib.mapAttrsToList (aliasName: hostName: {
            name = "alias_${helpers.sanitizeName aliasName}";
            value = {
              address = hosts.${hostName}.ip;
              name = "${aliasName}.${cfg.localDomain}";
              type = "A";
            };
          }) cfg.aliases
        );
    };
  };
}
