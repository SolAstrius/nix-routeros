# nix-routeros

[![CI](https://github.com/aleks-sidorenko/nix-routeros/actions/workflows/ci.yml/badge.svg)](https://github.com/aleks-sidorenko/nix-routeros/actions/workflows/ci.yml)

Declarative MikroTik RouterOS configuration using Nix. Define your router config with NixOS-module-style options, generate Terraform JSON via [terranix](https://terranix.org), and apply with [OpenTofu](https://opentofu.org).

## Quick Start

```bash
# Initialize from template
nix flake init -t github:aleks-sidorenko/nix-routeros

# Edit router.nix with your network settings, then:
export FLAKE_DIR=$(pwd)
nix run .#default          # Show generated Terraform JSON
nix run .#default.plan     # Plan changes
nix run .#default.apply    # Apply to router
```

## Usage

Add nix-routeros as a flake input:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-routeros = {
      url = "github:aleks-sidorenko/nix-routeros";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.terranix.follows = "terranix";
    };
  };

  outputs = { nixpkgs, nix-routeros, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.default = nix-routeros.lib.mkRouterDerivation {
        inherit pkgs system;
        modules = [ ./router.nix ];
      };
    };
}
```

Create `router.nix` with your configuration:

```nix
{
  routeros = {
    connection.gateway = "10.0.0.1";

    network = {
      subnet = "10.0.0.0/24";
      dhcp.server.range = "10.0.0.50-10.0.0.250";
    };

    bridge.ports = [ "ether2" "ether3" "ether4" "ether5" ];

    hosts.server = {
      ip = "10.0.0.10";
      mac = "AA:BB:CC:DD:EE:FF";
      comment = "Home server";
      aliases = [ "jellyfin" "home-assistant" ];
    };

    wifi = {
      enable = true;
      ssid = "MY-NETWORK";
      country = "united states";
    };
  };
}
```

For a full production example with SOPS secrets, WiFi, LTE, custom firewall rules, and 11 managed hosts, see [aleks-sidorenko/nix-config/infra/router](https://github.com/aleks-sidorenko/nix-config/tree/master/infra/router).

## Generated Scripts

`mkRouterDerivation` produces a derivation with four scripts (where `name` defaults to `"router"`):

| Script | Description |
|--------|-------------|
| `<name>-show` | Print the generated Terraform JSON to stdout |
| `<name>-plan` | Run `tofu init` + `tofu plan` — preview changes without applying |
| `<name>-apply` | Run `tofu init` + `tofu apply` — apply changes to the router |
| `<name>-destroy` | Run `tofu init` + `tofu destroy` — remove all managed resources |

The `plan`, `apply`, and `destroy` scripts require the `FLAKE_DIR` environment variable to be set to the flake root directory. They:

1. Decrypt secrets from SOPS (if `secretsFile` and `secrets` are configured)
2. Copy the generated `config.tf.json` into `stateDir`
3. Run `tofu init` and the corresponding command

```bash
export FLAKE_DIR=$(pwd)

# Preview what would change
nix run .#default.plan

# Apply changes to router
nix run .#default.apply

# Inspect the raw Terraform JSON
nix run .#default | jq .
```

If you use a custom `name`, the scripts are named accordingly (e.g. `name = "myrouter"` produces `myrouter-show`, `myrouter-plan`, etc.).

## Option Reference

### `routeros.connection`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `gateway` | string | `"10.0.0.1"` | Router IP for API connection |
| `username` | string | `"admin"` | RouterOS API username |
| `providerVersion` | string | `"~> 1.99"` | Terraform provider version |
| `scheme` | `"api"` \| `"apis"` | `"api"` | API connection scheme |

### `routeros.system`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `identity` | string | `"Router"` | Router hostname |
| `timezone` | string | `"UTC"` | System timezone |
| `services.<name>.enable` | bool | varies | Enable/disable IP service |
| `services.<name>.port` | int | varies | Service port |
| `services.<name>.allowedAddresses` | string \| null | null | Restrict to subnet |
| `ipv6.enable` | bool | `false` | Enable IPv6 |
| `macServer.enable` | bool | `true` | Enable MAC server |
| `neighborDiscovery.enable` | bool | `true` | Enable neighbor discovery |
| `bfd.enable` | bool | `true` | Enable BFD |
| `ipsec.dpdInterval` | string | `"2m"` | Dead Peer Detection interval |
| `ipsec.dpdMaxFailures` | int | `5` | Max DPD failures |

Services: `ssh` (22), `winbox` (8291), `api` (8728) enabled by default. `ftp` (21), `telnet` (23), `www` (80), `api-ssl` (8729) disabled by default.

### `routeros.network`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `subnet` | string | - | Network CIDR (e.g. `"10.0.0.0/24"`) |
| `dhcp.server.enable` | bool | - | Enable DHCP server |
| `dhcp.server.range` | string | - | Pool range (e.g. `"10.0.0.50-10.0.0.250"`) |
| `dhcp.server.leaseTime` | string | `"1d"` | Lease duration |
| `dhcp.client.enable` | bool | `true` | DHCP client on WAN |
| `dhcp.client.interface` | string | first WAN | Client interface |

### `routeros.bridge`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Create bridge interface |
| `ports` | list of string | `[]` | Interfaces to bridge |
| `adminMac` | string \| null | `null` | Manual admin MAC (null = auto) |

### `routeros.hosts`

Attribute set of hosts. Each host is a submodule:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ip` | string | - | IP address |
| `mac` | string | - | MAC address |
| `comment` | string | `""` | Description |
| `dhcp` | bool | `true` | Create static DHCP lease |
| `dns` | bool | `true` | Create DNS A record |
| `aliases` | list of string | `[]` | Additional DNS names pointing to this host's IP |

Hosts are the central source of truth — DHCP leases, DNS A records, and aliases are all derived from this option.

### `routeros.dns`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | - | Enable DNS |
| `upstream` | list of string | `["8.8.8.8" "4.4.4.4"]` | Upstream DNS servers |
| `localDomain` | string | `"local"` | Local domain suffix |
| `aliases` | attrs of string | `{}` | Extra aliases (name -> host from `routeros.hosts`) |

### `routeros.firewall`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | - | Enable firewall |
| `connectionTracking.udpTimeout` | string | `"10s"` | UDP tracking timeout |
| `addressLists` | attrs of (list of string) | `{}` | Firewall address lists |
| `filterRules` | list of attrset | `[]` | Additional filter rules (appended after preset) |
| `natRules` | list of attrset | `[]` | Additional NAT rules (appended after preset) |

The preset includes 13 filter rules (accept established, drop invalid, ICMP, loopback, IPsec, fasttrack, drop WAN DNS) and 2 NAT rules (masquerade, DNS redirect). User rules are appended after. Filter rules use `place_before` chaining for deterministic ordering.

### `routeros.wifi`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable CAPsMAN WiFi |
| `ssid` | string | `""` | Network name |
| `country` | string | `"united states"` | Regulatory country |
| `channels.2g.band` | string | `"2ghz-b/g/n"` | 2.4GHz band mode |
| `channels.5g.band` | string | `"5ghz-a/n/ac"` | 5GHz band mode |
| `security.authenticationTypes` | list of string | `["wpa-psk" "wpa2-psk"]` | Auth types |
| `security.encryption` | list of string | `["aes-ccm"]` | Encryption methods |

### `routeros.interfaces`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `wan` | list of string | `["ether1"]` | WAN interfaces |
| `lte.enable` | bool | `false` | Enable LTE |
| `lte.apn` | string | `""` | LTE APN |
| `lte.provider` | string | `""` | LTE provider name |

## Preset

Import `presets.router` (auto-imported by `mkRouterDerivation`) for a secure home router out of the box:

- SSH, WinBox, API enabled and restricted to LAN subnet
- FTP, Telnet, WWW, API-SSL disabled
- DHCP server + client enabled
- DNS with Google upstream, `.local` domain
- Full firewall with sane defaults
- IPv6 disabled
- WiFi and LTE opt-in

All preset values use `lib.mkDefault` — override them in your config without `mkForce`.

## Secrets

`mkRouterDerivation` supports [SOPS](https://github.com/getsops/sops) for secrets:

```nix
nix-routeros.lib.mkRouterDerivation {
  inherit pkgs system;
  modules = [ ./router.nix ];
  stateDir = "infra/router";
  secretsFile = "infra/router/secrets.yaml";
  secrets = {
    TF_VAR_routeros_password = "router-api-password";
    TF_VAR_wifi_password = "wifi-password";
    TF_VAR_state_passphrase = "state-passphrase";
  };
};
```

The `secrets` attrset maps environment variable names to SOPS key paths. The generated scripts decrypt them at runtime.

## Importing Existing Resources

For routers already configured, create an `imports.nix` to map existing resource IDs:

```nix
_: {
  import = [
    { to = "routeros_interface_bridge.bridge"; id = "*E"; }
    { to = "routeros_ip_dhcp_server.defconf"; id = "*1"; }
    # Discover IDs with: /interface bridge print show-ids
  ];
}
```

Pass it as a module:

```nix
modules = [ ./router.nix ./imports.nix ];
```

### Resource Naming Convention

Terraform resource names are derived from option values using a sanitization function:

- `-` and `.` replaced with `_`
- Names starting with a digit get `_` prepended
- DHCP leases: `routeros_ip_dhcp_server_lease.<sanitized_hostname>`
- DNS records: `routeros_ip_dns_record.<sanitized_hostname>`
- DNS aliases: `routeros_ip_dns_record.alias_<sanitized_alias>`

## Flake Outputs

| Output | Description |
|--------|-------------|
| `terranixModules.default` | All modules |
| `terranixModules.<module>` | Individual modules (connection, system, bridge, interfaces, dhcp, dns, firewall, wifi) |
| `presets.router` | Opinionated home router defaults |
| `lib.mkRouterDerivation` | Build derivation with show/plan/apply/destroy scripts |
| `lib.sanitizeName` | Name sanitization helper |
| `lib.networkAddress` | Derive network address from gateway IP |
| `lib.prefixLength` | Extract prefix length from CIDR |
| `templates.default` | Starter template for `nix flake init` |
| `formatter` | nixfmt-tree |

## Repository Layout

```
nix-routeros/
├── flake.nix
├── modules/
│   ├── default.nix        # Shared options (hosts, subnet, _lib)
│   ├── connection.nix     # Provider + connection
│   ├── system.nix         # Identity, clock, services
│   ├── bridge.nix         # Bridge interface + ports
│   ├── interfaces.nix     # WAN, LTE, interface lists
│   ├── dhcp.nix           # DHCP server/client + leases
│   ├── dns.nix            # DNS records + forwarding
│   ├── firewall.nix       # Filter rules, NAT, address lists
│   └── wifi.nix           # CAPsMAN configuration
├── presets/
│   └── router.nix         # Home router defaults
├── lib/
│   ├── helpers.nix        # sanitizeName, networkAddress, prefixLength
│   └── types.nix          # hostType, firewallRuleType, natRuleType
├── templates/default/     # nix flake init template
└── examples/basic/        # Minimal working example
```

## License

MIT
