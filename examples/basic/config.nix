{
  routeros = {
    connection.gateway = "10.0.0.1";

    network = {
      subnet = "10.0.0.0/24";
      dhcp.server.range = "10.0.0.50-10.0.0.250";
    };

    bridge.ports = [
      "ether2"
      "ether3"
      "ether4"
      "ether5"
    ];

    hosts = {
      server = {
        ip = "10.0.0.10";
        mac = "AA:BB:CC:DD:EE:FF";
        comment = "Home server";
        aliases = [
          "jellyfin"
          "home-assistant"
        ];
      };
    };

    # Optional: enable WiFi
    # wifi = {
    #   enable = true;
    #   ssid = "MY-NETWORK";
    #   country = "united states";
    # };
  };
}
