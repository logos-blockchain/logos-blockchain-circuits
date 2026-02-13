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
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-windows"
      ];

      forAll = lib.genAttrs systems;

      circuitsVersion = "0.4.1";  # TODO: Parametrize or make package per version available
      versions = import ./versions.nix;
      circuitsHashes = versions.${circuitsVersion};

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

          sha256 =
            if circuitsHashes ? ${system} then
              circuitsHashes.${system}
            else
              throw "logos-blockchain-circuits ${circuitsVersion} does not support ${system}.";
        in
        pkgs.stdenv.mkDerivation {
          pname = "logos-blockchain-circuits";
          version = circuitsVersion;
          phases = [ "installPhase" ];

          src = pkgs.fetchurl {
            url =
              "${githubBase}/v${circuitsVersion}"
              + "/logos-blockchain-circuits-v${circuitsVersion}-${os}-${arch}.tar.gz";
            inherit sha256;
          };

          installPhase = ''
            mkdir -p $out
            tar -xzf $src -C $out --strip-components=1
          '';

          meta = {
            platforms = [ system ];
          };

          passthru = {
            version = circuitsVersion;
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
