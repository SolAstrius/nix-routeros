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

    cacheSize = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "DNS cache size in KiB (raw integer; e.g. 16000 for 16000KiB). Null leaves the RouterOS default.";
    };

    useDohServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "DoH server URL (e.g. \"https://dns.example.com/dns-query\"). Null disables DoH.";
    };

    verifyDohCert = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Verify the DoH server's TLS certificate.";
    };

    staticRecords = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = ''
        Additional static DNS records (`/ip dns static`). Freeform attrsets — useful
        for absolute names (not appended to localDomain), non-A record types, FWD
        records, regex matches, blackhole entries, etc. Optional `resourceName` field
        becomes the Terraform resource id.
      '';
      example = lib.literalExpression ''
        [
          { resourceName = "blackhole_dahua"; name = "www.dahuap2p.com"; type = "A"; address = "0.0.0.1"; }
          { resourceName = "wildcard_daninc"; name = "*.daninc.ru"; type = "A"; address = "10.3.1.1"; }
        ]
      '';
    };

    adlists = lib.mkOption {
      type = lib.types.listOf (
        lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything)
      );
      default = [ ];
      description = ''
        DNS adlists (`/ip dns adlist`). Either bare URLs or freeform attrsets
        `{ url = "..."; ssl_verify = false; }`.
      '';
      example = lib.literalExpression ''
        [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
          { url = "https://example.com/blocklist"; ssl_verify = false; }
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_dns.settings = {
        allow_remote_requests = true;
        servers = cfg.upstream;
      }
      // lib.optionalAttrs (cfg.cacheSize != null) {
        cache_size = cfg.cacheSize;
      }
      // lib.optionalAttrs (cfg.useDohServer != null) {
        use_doh_server = cfg.useDohServer;
        verify_doh_cert = cfg.verifyDohCert;
      };

      routeros_ip_dns_adlist = builtins.listToAttrs (
        lib.imap0 (
          idx: entry:
          let
            attrs = if builtins.isAttrs entry then entry else { url = entry; };
          in
          {
            name = "adlist_${toString idx}";
            value = attrs;
          }
        ) cfg.adlists
      );

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
        )
        # Freeform static records (FQDNs, non-A types, blackholes, etc.)
        // builtins.listToAttrs (
          lib.imap0 (
            idx: rec_:
            let
              ruleName =
                if rec_ ? resourceName then
                  helpers.sanitizeName rec_.resourceName
                else
                  "static_${toString idx}";
              attrs = builtins.removeAttrs rec_ [ "resourceName" ];
            in
            {
              name = ruleName;
              value = attrs;
            }
          ) cfg.staticRecords
        );
    };
  };
}
