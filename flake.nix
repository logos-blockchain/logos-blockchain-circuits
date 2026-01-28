{
  description = "Logos Blockchain Circuits (GitHub Releases)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-windows"
      ];
      forAll = lib.genAttrs systems;

      circuitsVersion = "0.3.2";

      circuitsHashes = {
        x86_64-linux = "sha256-80+GrB3kBhwLHvNemme5Vig6tPDRRZC7xHps0DNonzM=";
        aarch64-darwin = "sha256-FbLgrHaa8djFEaA69WpZMB3uozkLT/abQiCWKrkzcsk=";
        x86_64-windows = "sha256-VOBUXlXNHTY0l91G+B1vybDfES0Y0HXhUytJIfFEiBA=";
      };

      githubBase = "https://github.com/logos-blockchain/logos-blockchain-circuits/releases/download";

      mkCircuits =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          os =
            if pkgs.stdenv.isLinux then
              "linux"
            else if pkgs.stdenv.isDarwin then
              "macos"
            else if pkgs.stdenv.isWindows then
              "windows"
            else
              throw "Unsupported OS";

          arch =
            if pkgs.stdenv.isx86_64 then
              "x86_64"
            else if pkgs.stdenv.isAarch64 then
              "aarch64"
            else
              throw "Unsupported architecture.";
        in
        pkgs.stdenv.mkDerivation {
          pname = "logos-blockchain-circuits";
          version = circuitsVersion;
          phases = [ "installPhase" ];

          src = pkgs.fetchurl {
            url =
              "${githubBase}/v${circuitsVersion}"
              + "/logos-blockchain-circuits-v${circuitsVersion}-${os}-${arch}.tar.gz";
            sha256 = circuitsHashes.${system};
          };

          installPhase = ''
            mkdir -p $out
            tar -xzf $src -C $out --strip-components=1
          '';

          meta = {
            platforms = [ system ];
          };
        };
    in
    {
      packages = forAll (
        system:
        let
          circuits = mkCircuits system;
        in
        {
          inherit circuits;
          default = circuits;
        }
      );
    };
}
