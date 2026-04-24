{
  description = "Extended example exercising routes, wireguard, vlans, ipv6, scheduler, scripts, multi-SSID CAPsMAN.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-routeros.url = "path:../..";
  };

  outputs =
    { nixpkgs, nix-routeros, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system}.default = nix-routeros.lib.mkRouterDerivation {
        inherit pkgs system;
        modules = [ ./router.nix ];
      };
    };
}
