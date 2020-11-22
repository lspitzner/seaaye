let setup = import ../package-setup.nix;
in setup // rec {
  all-version-strings =
    builtins.map
      (t: t.name)
      (setup.targets.hackage ++ setup.targets.stackage);
  all-materialization-paths =
    builtins.toString
      (builtins.map (n: "nix/materialized/" + n) all-version-strings);
  all-env-paths =
    builtins.toString
      (builtins.map (n: "nix/gcroots/" + n + "-envs") all-version-strings);

}