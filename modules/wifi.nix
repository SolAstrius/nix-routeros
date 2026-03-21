{ config, lib, ... }:
let
  cfg = config.routeros.wifi;
in
{
  options.routeros.wifi = {
    enable = lib.mkEnableOption "WiFi via CAPsMAN";

    ssid = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "WiFi network name (SSID).";
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
          description = "2.4GHz band mode.";
        };
        channelWidth = lib.mkOption {
          type = lib.types.str;
          default = "20mhz";
          description = "2.4GHz control channel width.";
        };
      };
      "5g" = {
        band = lib.mkOption {
          type = lib.types.str;
          default = "5ghz-a/n/ac";
          description = "5GHz band mode.";
        };
        channelWidth = lib.mkOption {
          type = lib.types.str;
          default = "20mhz";
          description = "5GHz control channel width.";
        };
      };
    };

    datapath = {
      clientToClientForwarding = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow client-to-client traffic.";
      };
      localForwarding = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable local forwarding.";
      };
    };

    security = {
      authenticationTypes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "wpa-psk"
          "wpa2-psk"
        ];
        description = "Authentication types.";
      };
      encryption = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "aes-ccm" ];
        description = "Encryption methods.";
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
      description = "CAPsMAN provisioning rules.";
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_capsman_channel = {
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

      routeros_capsman_datapath.datapath = {
        name = "datapath";
        bridge = "bridge";
        client_to_client_forwarding = cfg.datapath.clientToClientForwarding;
        local_forwarding = cfg.datapath.localForwarding;
      };

      routeros_capsman_security.security = {
        name = "security";
        authentication_types = cfg.security.authenticationTypes;
        encryption = cfg.security.encryption;
        passphrase = "\${var.wifi_password}";
      };

      routeros_capsman_configuration =
        let
          chains = [
            0
            1
            2
            3
          ];
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

      routeros_capsman_manager.manager = {
        enabled = true;
        upgrade_policy = "require-same-version";
      };

      routeros_capsman_manager_interface.bridge = {
        disabled = false;
        interface = "bridge";
      };

      routeros_capsman_provisioning = builtins.listToAttrs (
        builtins.map (prov: {
          name = prov.name;
          value = {
            action = "create-dynamic-enabled";
            hw_supported_modes = prov.hw_supported_modes;
            master_configuration = prov.master_configuration;
            name_format = "prefix-identity";
            name_prefix = prov.name_prefix;
          };
        }) cfg.provisioning
      );
    };
  };
}
