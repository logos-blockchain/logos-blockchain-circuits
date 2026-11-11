{
  description = "Logos Blockchain Circuits (GitHub Releases)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # The Windows toolchain. It must match Logos Rapidsnark's, so that everything is built with the same compiler and
    # runtime libraries.
    logos-nix.url = "github:logos-co/logos-nix";
    # Keep this tag the same as deps/rapidsnark/VERSION. Using `scripts/update-rapidsnark.sh` updates both.
    logos-blockchain-rapidsnark.url = "github:logos-blockchain/logos-blockchain-rapidsnark/v0.0.8-logos.1-rc.5";
    logos-blockchain-rapidsnark.inputs.logos-nix.follows = "logos-nix";
  };

  outputs =
    { nixpkgs, logos-nix, ... }:
    let
      lib = nixpkgs.lib;

      buildPkgs = logos-nix.legacyPackages.x86_64-linux;
      windowsPkgs = buildPkgs.pkgsWindows;

      # mman-win32: sys/mman.h for Windows. The circom-generated main.cpp uses mmap.
      windowsMman = windowsPkgs.stdenv.mkDerivation {
        pname = "mman-win32";
        version = "0-unstable-2026-11-03";
        src = buildPkgs.fetchFromGitHub {
          owner = "alitrack";
          repo = "mman-win32";
          rev = "780b16cdbc8e845eaa2bef3baf762011f6a7036d";
          hash = "sha256-QtGKcwz3M8mOAIXUmHQTuCUNuHbnYAkRS4RHMmJQrOw=";
        };
        nativeBuildInputs = [ buildPkgs.cmake ];
        cmakeFlags = [ "-DBUILD_SHARED_LIBS=OFF" ];
      };

      windowsBuildInputs = [
        windowsPkgs.nlohmann_json
        windowsMman
      ];

      windowsCross =
        let
          cc = windowsPkgs.stdenv.cc;
        in
        # Uses a native shell, since the code is compiled on this machine.
        # The `*_x86_64_pc_windows_gnu` variables below make the Windows target use MinGW to link and compile C code.
        buildPkgs.mkShell {
          packages = [
            cc
            buildPkgs.gnumake
          ];

          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${cc.targetPrefix}gcc";
          CC_x86_64_pc_windows_gnu = "${cc.targetPrefix}gcc";
          CXX_x86_64_pc_windows_gnu = "${cc.targetPrefix}g++";
          AR_x86_64_pc_windows_gnu = "${cc.targetPrefix}ar";
          # Rust expects pthreads, but logos-nix's MinGW uses mcfgthread.
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS = builtins.concatStringsSep " " [
            "-L native=${windowsPkgs.windows.pthreads}/lib"
            "-C link-arg=-l:libmcfgthread.a"
            "-C link-arg=-lntdll"
            "-C link-arg=-lkernel32"
          ];
        };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-windows"
      ];

      forAll = lib.genAttrs systems;

      cargoToml = builtins.fromTOML (builtins.readFile ./rust/Cargo.toml);
      circuitsVersion = cargoToml.workspace.package.version;
      versions = builtins.fromJSON (builtins.readFile ./circuits-nix-hashes.json);
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
      packages = lib.recursiveUpdate (forAll (
        system:
        let
          circuits = mkCircuits system;
        in
        {
          inherit circuits;
          default = circuits;
        }
      )) { x86_64-linux.windows-mman = windowsMman; };

      devShells.x86_64-linux.windows-cross = windowsCross;
    };
}
