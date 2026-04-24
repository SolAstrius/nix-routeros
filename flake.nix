{
  description = "NixOS-module-style interface for configuring MikroTik RouterOS via terranix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      terranix,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      helpers = import ./lib/helpers.nix { inherit lib; };
    in
    {
      # Terranix modules — system-independent
      terranixModules = {
        default = ./modules;
        connection = ./modules/connection.nix;
        system = ./modules/system.nix;
        bridge = ./modules/bridge.nix;
        interfaces = ./modules/interfaces.nix;
        dhcp = ./modules/dhcp.nix;
        dns = ./modules/dns.nix;
        firewall = ./modules/firewall.nix;
        wifi = ./modules/wifi.nix;
      };

      # Presets
      presets.router = ./presets/router.nix;

      # Lib helpers
      lib = helpers // {
        mkRouterDerivation =
          {
            pkgs,
            system,
            name ? "router",
            modules ? [ ],
            stateDir ? ".",
            secretsFile ? null,
            secrets ? { },
            # Enable OpenTofu state encryption (1.7+). When true, an
            # encryption.tf HCL file is written alongside config.tf.json
            # (HCL because the encryption block doesn't accept JSON). The
            # passphrase comes from $TF_VAR_state_passphrase — wire it via
            # the `secrets` attrset (e.g. TF_VAR_state_passphrase = "router/state_passphrase";).
            stateEncryption ? false,
          }:
          let
            terraformConfiguration = terranix.lib.terranixConfiguration {
              inherit system;
              extraArgs = { inherit lib pkgs; };
              modules = [ self.presets.router ] ++ modules;
            };

            tofu = "${pkgs.opentofu}/bin/tofu";
            sops = "${pkgs.sops}/bin/sops";

            # The encryption block must be HCL — OpenTofu doesn't parse it
            # in JSON syntax (https://github.com/opentofu/opentofu/issues/2174).
            encryptionTf = pkgs.writeText "encryption.tf" ''
              terraform {
                encryption {
                  key_provider "pbkdf2" "default" {
                    passphrase = var.state_passphrase
                  }
                  method "aes_gcm" "default" {
                    keys = key_provider.pbkdf2.default
                  }
                  state {
                    method   = method.aes_gcm.default
                    enforced = true
                  }
                  plan {
                    method   = method.aes_gcm.default
                    enforced = true
                  }
                }
              }
            '';

            resolveRoot = ''
              if [[ -z "''${FLAKE_DIR:-}" ]]; then
                echo "Error: FLAKE_DIR not set. Export it to the flake root directory."
                exit 1
              fi
              REPO_ROOT="$FLAKE_DIR"
            '';

            # Translate a slash-separated SOPS path ("bulgaria/api_password")
            # into the bracketed --extract syntax ('["bulgaria"]["api_password"]').
            sopsPath =
              path:
              lib.concatStrings (builtins.map (seg: "[\"${seg}\"]") (lib.splitString "/" path));

            loadSecrets =
              if secretsFile != null && secrets != { } then
                lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (
                    envVar: sopsKey:
                    ''export ${envVar}=$(${sops} -d --extract '${sopsPath sopsKey}' "$REPO_ROOT/${secretsFile}")''
                  ) secrets
                )
              else
                "";

            tfSetup = ''
              cd "$REPO_ROOT/${stateDir}"
              cp -f ${terraformConfiguration} config.tf.json
              ${lib.optionalString stateEncryption "cp -f ${encryptionTf} encryption.tf"}
            '';

            show = pkgs.writeShellScriptBin "${name}-show" ''
              set -euo pipefail
              cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
            '';

            plan = pkgs.writeShellScriptBin "${name}-plan" ''
              set -euo pipefail
              ${resolveRoot}
              ${loadSecrets}
              ${tfSetup}
              ${tofu} init -input=false
              ${tofu} plan
            '';

            apply = pkgs.writeShellScriptBin "${name}-apply" ''
              set -euo pipefail
              ${resolveRoot}
              ${loadSecrets}
              ${tfSetup}
              ${tofu} init -input=false
              ${tofu} apply
            '';

            destroy = pkgs.writeShellScriptBin "${name}-destroy" ''
              set -euo pipefail
              ${resolveRoot}
              ${loadSecrets}
              ${tfSetup}
              ${tofu} init -input=false
              ${tofu} destroy
            '';
          in
          show // { inherit plan apply destroy; };
      };

      # Templates
      templates.default = {
        path = ./templates/default;
        description = "Basic nix-routeros configuration";
      };

      # Formatter — per-system output
      formatter = builtins.listToAttrs (
        builtins.map
          (system: {
            name = system;
            value = nixpkgs.legacyPackages.${system}.nixfmt-tree;
          })
          [
            "x86_64-linux"
            "aarch64-linux"
            "x86_64-darwin"
            "aarch64-darwin"
          ]
      );
    };
}
