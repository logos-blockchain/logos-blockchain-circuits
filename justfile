prettify:
    nix shell nixpkgs#clang-tools -c clang-format -i src/**.cpp src/**.hpp

# Run a Sage script in a Docker container.
# Output is written relative to the script's directory.
# Example: just sage-run blend/generate_inputs_for_poq.py 1 10 5 0
#   -> blend/input.json
sage-run script +args='':
    docker run --rm \
        -v "{{justfile_directory()}}:/work" \
        -w "/work/$(dirname '{{script}}')" \
        sagemath/sagemath sage "$(basename '{{script}}')" {{args}}
