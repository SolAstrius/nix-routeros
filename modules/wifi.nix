{ config, lib, ... }:
let
  cfg = config.routeros.wifi;
  helpers = config.routeros._lib;

  # Whether the user is using the simple single-SSID convenience path.
  simpleMode =
    cfg.enable
    && cfg.ssid != ""
    && cfg.capsman.configurations == { }
    && cfg.capsman.channels == { };

  # Simple-mode resources (preserves the original 2G+5G defaults).
  simpleChannels = {
    channel_2G = {
      name = "2G";
      band = cfg.channels."2g".band;
      control_channel_width = cfg.channels."2g".channelWidth;
    };
    channel_5G = {
      name = "5G";
      band = cfg.channels."5g".band;
      control_channel_width = cfg.channels."5g".channelWidth;
    };
  };

  simpleConfigurations =
    let
      chains = [ 0 1 2 3 ];
      mkConfig = name: channelName: {
        inherit name;
        channel.config = channelName;
        country = cfg.country;
        datapath.config = "datapath";
        installation = "any";
        mode = "ap";
        rx_chains = chains;
        security.config = "security";
        ssid = cfg.ssid;
        tx_chains = chains;
      };
    in
    {
      config_2G = mkConfig "2G" "2G";
      config_5G = mkConfig "5G" "5G";
    };

  simpleDatapath = {
    datapath = {
      name = "datapath";
      bridge = "bridge";
      client_to_client_forwarding = cfg.datapath.clientToClientForwarding;
      local_forwarding = cfg.datapath.localForwarding;
    };
  };

  simpleSecurity = {
    security = {
      name = "security";
      authentication_types = cfg.security.authenticationTypes;
      encryption = cfg.security.encryption;
      passphrase = "\${var.wifi_password}";
    };
  };

  # Generic provisioning rule renderer — passes through any freeform fields.
  mkProvisioningRule =
    rule:
    let
      base = {
        action = rule.action or "create-dynamic-enabled";
        name_format = rule.name_format or "prefix-identity";
      }
      // lib.optionalAttrs (rule ? hw_supported_modes) {
        hw_supported_modes = rule.hw_supported_modes;
      }
      // lib.optionalAttrs (rule ? master_configuration) {
        master_configuration = rule.master_configuration;
      }
      // lib.optionalAttrs (rule ? name_prefix) {
        name_prefix = rule.name_prefix;
      }
      // lib.optionalAttrs (rule ? identity_regexp) {
        identity_regexp = rule.identity_regexp;
      };
      extras = builtins.removeAttrs rule [
        "name"
        "action"
        "name_format"
        "hw_supported_modes"
        "master_configuration"
        "name_prefix"
        "identity_regexp"
      ];
    in
    {
      name = helpers.sanitizeName rule.name;
      value = base // extras;
    };

  # Map an attrset of named items to terraform resources, injecting `name = key`.
  mkNamedAttrs = attrs: lib.mapAttrs (n: v: { name = n; } // v) attrs;
in
{
  options.routeros.wifi = {
    enable = lib.mkEnableOption "WiFi via CAPsMAN";

    ssid = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        WiFi network name (SSID) for simple-mode single-SSID setups. When using
        `capsman.configurations` for multi-SSID setups, this is ignored.
      '';
    };

    country = lib.mkOption {
      type = lib.types.str;
      default = "united states";
      description = "Regulatory country for WiFi channels.";
    };

    channels = {
      "2g" = {
        band = lib.mkOption {
          type = lib.types.str;
          default = "2ghz-b/g/n";
          description = "2.4GHz band mode (simple mode).";
        };
        channelWidth = lib.mkOption {
          type = lib.types.str;
          default = "20mhz";
          description = "2.4GHz control channel width (simple mode).";
        };
      };
      "5g" = {
        band = lib.mkOption {
          type = lib.types.str;
          default = "5ghz-a/n/ac";
          description = "5GHz band mode (simple mode).";
        };
        channelWidth = lib.mkOption {
          type = lib.types.str;
          default = "20mhz";
          description = "5GHz control channel width (simple mode).";
        };
      };
    };

    datapath = {
      clientToClientForwarding = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow client-to-client traffic (simple mode).";
      };
      localForwarding = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable local forwarding (simple mode).";
      };
    };

    security = {
      authenticationTypes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "wpa-psk"
          "wpa2-psk"
        ];
        description = "Authentication types (simple mode).";
      };
      encryption = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "aes-ccm" ];
        description = "Encryption methods (simple mode).";
      };
    };

    provisioning = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [
        {
          name = "prov_5G";
          hw_supported_modes = [ "ac" ];
          master_configuration = "5G";
          name_prefix = "5G";
        }
        {
          name = "prov_2G";
          hw_supported_modes = [ "gn" ];
          master_configuration = "2G";
          name_prefix = "2G";
        }
      ];
      description = ''
        CAPsMAN provisioning rules. Each entry must have `name`. Other fields
        (`hw_supported_modes`, `master_configuration`, `name_prefix`,
        `identity_regexp`, `action`, `name_format`) and any extra freeform fields
        pass through to the routeros_capsman_provisioning resource.
      '';
    };

    capsman = {
      channels = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
        default = { };
        description = ''
          Named CAPsMAN channels (`/caps-man channel`), keyed by channel name.
          Setting any entry here switches off the simple `channels."2g"/.5g"` path —
          you become responsible for declaring all channels you want.
        '';
        example = lib.literalExpression ''
          {
            ch-2g-1st = { band = "2ghz-g/n"; frequency = 2437; };
            ch-5g-1st = { band = "5ghz-a/n/ac"; frequency = 5260; };
          }
        '';
      };

      securities = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
        default = { };
        description = "Named CAPsMAN security profiles (`/caps-man security`).";
        example = lib.literalExpression ''
          {
            security_main = {
              authentication_types = [ "wpa-psk" "wpa2-psk" ];
              encryption = [ "aes-ccm" ];
              passphrase = "\''${var.wifi_password}";
            };
          }
        '';
      };

      datapaths = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
        default = { };
        description = "Named CAPsMAN datapaths (`/caps-man datapath`).";
      };

      configurations = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
        default = { };
        description = ''
          Named CAPsMAN configurations (`/caps-man configuration`). Setting any
          entry here switches off the simple single-SSID path — you become
          responsible for declaring all configurations.
        '';
        example = lib.literalExpression ''
          {
            cfg-2g-1st = {
              channel.config = "ch-2g-1st";
              country = "russia3";
              datapath.config = "datapath1";
              installation = "indoor";
              mode = "ap";
              security.config = "security1";
              ssid = "Net92";
            };
          }
        '';
      };

      manager = {
        upgradePolicy = lib.mkOption {
          type = lib.types.str;
          default = "require-same-version";
          description = "CAPsMAN upgrade policy.";
        };
        packagePath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Package path for CAPsMAN upgrades (e.g. \"/upgrades/\").";
        };
        certificate = lib.mkOption {
          type = lib.types.str;
          default = "auto";
          description = "Certificate for CAPsMAN.";
        };
        caCertificate = lib.mkOption {
          type = lib.types.str;
          default = "auto";
          description = "CA certificate for CAPsMAN.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_capsman_channel = if simpleMode then simpleChannels else mkNamedAttrs cfg.capsman.channels;

      routeros_capsman_datapath =
        if cfg.capsman.datapaths != { } then
          mkNamedAttrs cfg.capsman.datapaths
        else
          simpleDatapath;

      routeros_capsman_security =
        if cfg.capsman.securities != { } then
          mkNamedAttrs cfg.capsman.securities
        else
          simpleSecurity;

      routeros_capsman_configuration =
        if simpleMode then simpleConfigurations else mkNamedAttrs cfg.capsman.configurations;

      routeros_capsman_manager.manager = {
        enabled = true;
        upgrade_policy = cfg.capsman.manager.upgradePolicy;
        certificate = cfg.capsman.manager.certificate;
        ca_certificate = cfg.capsman.manager.caCertificate;
      }
      // lib.optionalAttrs (cfg.capsman.manager.packagePath != null) {
        package_path = cfg.capsman.manager.packagePath;
      };

      routeros_capsman_manager_interface.bridge = {
        disabled = false;
        interface = "bridge";
      };

      routeros_capsman_provisioning = builtins.listToAttrs (
        builtins.map mkProvisioningRule cfg.provisioning
      );
    };
  };
}
