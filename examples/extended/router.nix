{ config, lib, ... }:
{
  routeros = {
    connection.gateway = "10.3.0.1";

    network = {
      subnet = "10.3.0.0/16";
      dhcp.server.range = "10.3.128.1-10.3.255.254";
    };

    bridge.ports = [
      "ether2"
      "ether3"
      "ether4"
      "ether5"
    ];

    interfaces.ethernet = {
      ether1 = { comment = "ISP WAN"; };
      ether2 = { comment = "2F D-Link"; };
      ether9 = { comment = "Aldebaran (server)"; };
    };

    vlans = {
      bridgeFiltering = true;
      bridgeVlans = [
        {
          name = "default_lan";
          vlanIds = 1;
          untagged = [ "bridge" "ether2" "ether3" ];
          comment = "Default LAN";
        }
        {
          name = "vlan20_aldebaran";
          vlanIds = 20;
          tagged = [ "bridge" "ether9" ];
          comment = "Aldebaran direct path";
        }
      ];
      interfaces.vlan20 = {
        vlanId = 20;
        interface = "bridge";
        comment = "Aldebaran direct path L3";
      };
    };

    routes = {
      ipv4 = [
        { name = "default"; dst_address = "0.0.0.0/0"; gateway = "185.9.72.254"; check_gateway = "ping"; }
        { name = "warsaw"; dst_address = "10.0.0.1/32"; gateway = "wg-backbone"; comment = "Warsaw"; }
        { name = "bulgaria"; dst_address = "10.0.0.4/32"; gateway = "wg-bulgaria"; comment = "Bulgaria"; }
      ];
      ipv6 = [
        { name = "default_v6"; dst_address = "::/0"; gateway = "wg-backbone"; }
      ];
    };

    wireguard = {
      interfaces = {
        wg-backbone = { listenPort = 51820; mtu = 1420; };
        wg-bulgaria = { listenPort = 55555; mtu = 1380; };
      };
      peers = [
        {
          name = "moscow-backbone";
          interface = "wg-backbone";
          publicKey = "+WqDPeaDcHbBLZWBg0tBRlrFEu1gSPXU1FBdVWQQCVs=";
          allowedAddress = [
            "10.0.0.6/32"
            "10.0.1.0/24"
            "::/0"
          ];
          endpointAddress = "94.103.92.214";
          endpointPort = 51820;
          persistentKeepalive = "25s";
          comment = "Moscow backbone (10.0.0.6)";
        }
        {
          name = "bulgaria-direct";
          interface = "wg-bulgaria";
          publicKey = "/7EXfxgmujAg0QeYXHZi8QwPhEc7lTfpr2H+ifMgCWc=";
          allowedAddress = "10.99.88.2/32";
          comment = "bulgaria-diag";
        }
      ];
    };

    ipv6 = {
      enable = true;
      addresses = [
        { name = "wg_v6"; address = "2a05:f480:2400:1cf7:3::1/128"; interface = "wg-backbone"; advertise = false; }
        { name = "bridge_v6"; address = "2a05:f480:2400:1cf7:3::1/80"; interface = "bridge"; advertise = false; }
      ];
      pools = {
        pool-lan = {
          prefix = "2a05:f480:2400:1cf7:3:0:100:0/104";
          prefix_length = 128;
        };
      };
      addressLists = {
        mesh-sources = [
          { address = "2a05:f480:2400::/48"; comment = "Vultr mesh"; }
          { address = "2a01:4f9:2a:1324::/64"; comment = "Hetzner"; }
        ];
      };
      ndPrefixes = [
        { name = "lan_prefix"; prefix = "2a05:f480:2400:1cf7:3::/80"; interface = "bridge"; autonomous = false; }
      ];
      firewall = {
        natRules = [
          {
            name = "nat66_mesh_to_lan";
            action = "masquerade";
            chain = "srcnat";
            comment = "NAT mesh to LAN";
            out_interface = "bridge";
            src_address = "2a05:f480:2400:1cf7::/64";
          }
        ];
        mangleRules = [
          {
            name = "mark_warsaw";
            action = "mark-packet";
            chain = "prerouting";
            comment = "Mesh: Warsaw";
            in_interface = "wg-backbone";
            new_packet_mark = "mesh";
            passthrough = false;
            src_address = "2a05:f480:2400:1cf7::1/128";
          }
        ];
      };
    };

    dns = {
      enable = true;
      upstream = [ "8.8.8.8" "8.8.4.4" ];
      cacheSize = 16000;
      useDohServer = "https://dns.example.com/dns-query";
      verifyDohCert = true;
      adlists = [
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        { url = "https://example.com/blocklist"; ssl_verify = false; }
      ];
      staticRecords = [
        { resourceName = "blackhole_dahua"; name = "www.dahuap2p.com"; type = "A"; address = "0.0.0.1"; }
        { resourceName = "wildcard_daninc"; name = "*.daninc.ru"; type = "A"; address = "10.3.1.1"; }
      ];
    };

    wifi = {
      enable = true;
      country = "russia3";
      capsman = {
        channels = {
          ch-2g-0th = { band = "2ghz-g/n"; frequency = [ 2412 ]; };
          ch-2g-1st = { band = "2ghz-g/n"; frequency = [ 2437 ]; };
          ch-2g-3rd = { band = "2ghz-g/n"; frequency = [ 2462 ]; };
          ch-5g-0th = { band = "5ghz-a/n/ac"; frequency = [ 5180 ]; };
          ch-5g-1st = { band = "5ghz-a/n/ac"; frequency = [ 5260 ]; };
          ch-5g-3rd = { band = "5ghz-a/n/ac"; frequency = [ 5320 ]; };
        };
        securities.security1 = {
          authentication_types = [ "wpa-psk" "wpa2-psk" ];
          encryption = [ "aes-ccm" ];
          passphrase = "\${var.wifi_password}";
        };
        datapaths.datapath1 = {
          bridge = "bridge";
          client_to_client_forwarding = true;
          local_forwarding = false;
        };
        configurations =
          let
            mkCfg = floor: band: chan: ssid: {
              channel.config = chan;
              country = "russia3";
              datapath.config = "datapath1";
              installation = "indoor";
              mode = "ap";
              security.config = "security1";
              ssid = ssid;
            };
          in
          {
            cfg-2g-0th = mkCfg "0th" "2g" "ch-2g-0th" "Net92";
            cfg-2g-1st = mkCfg "1st" "2g" "ch-2g-1st" "Net92";
            cfg-2g-3rd = mkCfg "3rd" "2g" "ch-2g-3rd" "Net92";
            cfg-5g-0th = mkCfg "0th" "5g" "ch-5g-0th" "Net92.5G";
            cfg-5g-1st = mkCfg "1st" "5g" "ch-5g-1st" "Net92.5G";
            cfg-5g-3rd = mkCfg "3rd" "5g" "ch-5g-3rd" "Net92.5G";
          };
        manager.packagePath = "/upgrades/";
      };
      provisioning = [
        { name = "prov_0th_2g"; identity_regexp = "0th-floor"; hw_supported_modes = [ "gn" ]; master_configuration = "cfg-2g-0th"; name_prefix = "0th-2g"; }
        { name = "prov_0th_5g"; identity_regexp = "0th-floor"; hw_supported_modes = [ "a" ]; master_configuration = "cfg-5g-0th"; name_prefix = "0th-5g"; }
        { name = "prov_1st_2g"; identity_regexp = "1st-floor"; hw_supported_modes = [ "gn" ]; master_configuration = "cfg-2g-1st"; name_prefix = "1st-2g"; }
        { name = "prov_1st_5g"; identity_regexp = "1st-floor"; hw_supported_modes = [ "a" ]; master_configuration = "cfg-5g-1st"; name_prefix = "1st-5g"; }
        { name = "prov_3rd_2g"; identity_regexp = "3rd-floor"; hw_supported_modes = [ "gn" ]; master_configuration = "cfg-2g-3rd"; name_prefix = "3rd-2g"; }
        { name = "prov_3rd_5g"; identity_regexp = "3rd-floor"; hw_supported_modes = [ "a" ]; master_configuration = "cfg-5g-3rd"; name_prefix = "3rd-5g"; }
      ];
    };

    scheduler.tailscale-route-refresh = {
      interval = "1h";
      onEvent = "/system script run update-tailscale-routes";
      startTime = "00:05:00";
    };

    scripts.update-tailscale-routes = {
      owner = "sol";
      source = ''
        :local resolvedIPs [:resolve "controlplane.tailscale.com"]
        :foreach ip in=$resolvedIPs do={
          /ip route add dst-address="$ip/32" gateway=wg-backbone comment="Tailscale-ControlPlane"
        }
      '';
    };

    firewall = {
      enable = true;
      addressLists.cameras = [
        "10.3.2.4"
        "10.3.2.12"
        "10.3.2.14"
      ];
      filterRules = [
        {
          name = "drop_cameras_external";
          action = "drop";
          chain = "forward";
          comment = "cameras: block external access";
          connection_state = "new";
          dst_address = "!10.3.0.0/16";
          src_address_list = "cameras";
        }
      ];
    };
  };
}
