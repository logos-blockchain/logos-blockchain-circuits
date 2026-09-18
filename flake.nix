{
  description = "Logos Blockchain Circuits (GitHub Releases)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      # Nix cannot instantiate a Windows package set: there is no
      # `nixpkgs.legacyPackages.x86_64-windows`, so the old entry here made
      # `packages.x86_64-windows` fail with "attribute 'x86_64-windows'
      # missing". Windows is a cross TARGET, listed in `crossTargets` below.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      cargoToml = builtins.fromTOML (builtins.readFile ./rust/Cargo.toml);
      circuitsVersion = cargoToml.workspace.package.version;
      versions = builtins.fromJSON (builtins.readFile ./circuits-nix-hashes.json);
      circuitsHashes = versions.${circuitsVersion};

      githubBase = "https://github.com/logos-blockchain/logos-blockchain-circuits/releases/download";

      # Which release asset a target system maps to. Derived from the system
      # string rather than from stdenv, so a target nixpkgs cannot instantiate
      # (x86_64-windows) can still be named.
      targetOs =
        target:
        if lib.hasSuffix "-linux" target then
          "linux"
        else if lib.hasSuffix "-darwin" target then
          "macos"
        else if lib.hasSuffix "-windows" target || lib.hasSuffix "-windows-gnu" target then
          "windows"
        else
          throw "Unsupported OS in ${target}";

      # The `-gnu` targets are the MinGW cross build, published alongside the
      # MSYS2 one: same circuits, compiled and symbol-isolated with the
      # toolchain a cross-compiling consumer links with, so its own libstdc++
      # and nlohmann COMDATs satisfy the archives. They also ship libmman.a,
      # which the circuit objects need for mmap/munmap.
      targetArch =
        target:
        let
          base =
            if lib.hasPrefix "x86_64-" target then
              "x86_64"
            else if lib.hasPrefix "aarch64-" target then
              "aarch64"
            else
              throw "Unsupported architecture in ${target}";
        in
        if lib.hasSuffix "-gnu" target then "${base}-gnu" else base;

      # `buildSystem` is what nixpkgs instantiates, `target` is whose archives we
      # fetch. They differ only for cross targets: these are prebuilt artifacts,
      # so unpacking them needs no toolchain for the target at all.
      mkCircuitsFor =
        { buildSystem, target }:
        let
          pkgs = nixpkgs.legacyPackages.${buildSystem};

          os = targetOs target;
          arch = targetArch target;

          sha256 =
            if circuitsHashes ? ${target} then
              circuitsHashes.${target}
            else
              throw "logos-blockchain-circuits ${circuitsVersion} does not support ${target}.";
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
            platforms = [ buildSystem ];
          };

          passthru = {
            version = circuitsVersion;
          };
        };
      mkCircuits = system: mkCircuitsFor {
        buildSystem = system;
        target = system;
      };

      # Cross targets nix cannot build *on*. Published under each build platform
      # as `circuits-<os>-<arch>`, the same shape zerokit and logos-delivery use,
      # so a consumer cross-compiling for Windows can reach them.
      crossTargets = [
        "x86_64-windows"
        "x86_64-windows-gnu"
      ];

      nativeSystems = builtins.filter (s: !(lib.hasSuffix "-windows" s)) systems;
    in
    {
      packages = lib.genAttrs nativeSystems (
        system:
        let
          circuits = mkCircuits system;
        in
        {
          inherit circuits;
          default = circuits;
        }
        // lib.listToAttrs (
          map (target: {
            name = "circuits-${targetOs target}-${targetArch target}";
            value = mkCircuitsFor {
              buildSystem = system;
              target = target;
            };
          }) (builtins.filter (t: circuitsHashes ? ${t}) crossTargets)
        )
      );
    };
}
