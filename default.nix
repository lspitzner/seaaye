let
  nixpkgs = import <nixpkgs> {};
  mainScript = nixpkgs.writeShellScriptBin "seaaye" "echo Hello World";
in
  nixpkgs.stdenv.mkDerivation rec {
    name = "seaaye";
    phases = [ "installPhase" "testPhase" ];
    src = nixpkgs.lib.cleanSource ./src;
    buildInputs = [ nixpkgs.bash nixpkgs.shellcheck ];
    installPhase = ''
      mkdir -p "$out"/bin
      mkdir -p "$out"/lib/seaaye
      find -L "$src"
      cp "$src"/seaaye.sh "$out/bin/seaaye"
      cp -t "$out/lib/seaaye/" "$src/main.nix" "$src/Makefile" "$src/Makefile-shell"
      cp -r "$src/nix" "$out/lib/seaaye/nix"
      cp -r "$src/scripts" "$out/lib/seaaye/scripts"
    '';
    testPhase = ''
      shellcheck "$out/bin/seaaye" "$out/lib/seaaye/scripts"/*.sh
    '';
  }
