prettify:
    nix shell nixpkgs#clang-tools -c clang-format -i src/**.cpp src/**.hpp
