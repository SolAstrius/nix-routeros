{ config, lib, ... }:
let
  cfg = config.routeros.connection;
in
{
  options.routeros.connection = {
    gateway = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.1";
      description = "Router IP address for API connection.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "RouterOS API username.";
    };

    providerVersion = lib.mkOption {
      type = lib.types.str;
      default = "~> 1.99";
      description = "RouterOS Terraform provider version constraint.";
    };

    scheme = lib.mkOption {
      type = lib.types.enum [ "api" "apis" ];
      default = "api";
      description = "API connection scheme (api for plaintext, apis for TLS).";
    };
  };

  config = {
    terraform = {
      required_providers.routeros = {
        source = "terraform-routeros/routeros";
        version = cfg.providerVersion;
      };
    };

    provider.routeros = {
      hosturl = "${cfg.scheme}://${cfg.gateway}";
      username = "\${var.routeros_username}";
      password = "\${var.routeros_password}";
    };

    variable = {
      routeros_username = {
        type = "string";
        default = cfg.username;
        description = "RouterOS API username";
      };
      routeros_password = {
        type = "string";
        sensitive = true;
        description = "RouterOS API password";
      };
      wifi_password = {
        type = "string";
        sensitive = true;
        description = "WiFi password for CAPsMAN security";
        default = "";
      };
      state_passphrase = {
        type = "string";
        sensitive = true;
        description = "Passphrase for OpenTofu state encryption (min 16 chars)";
        default = "";
      };
    };
  };
}
