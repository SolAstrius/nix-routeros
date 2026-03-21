{
  description = "nix-routeros basic example";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-routeros = {
      url = "path:../../";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.terranix.follows = "terranix";
    };
  };

  outputs = { nixpkgs, terranix, nix-routeros, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.default = nix-routeros.lib.mkRouterDerivation {
        inherit pkgs system;
        name = "router";
        modules = [ ./config.nix ];
        stateDir = ".";
      };
    };
}
