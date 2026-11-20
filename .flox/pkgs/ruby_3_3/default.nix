{
  mkRuby,
  mkRubyVersion,
}:

# Ruby 3.3 for projects that pin an exact 3.3.x and need its security fixes.
# nixpkgs dropped ruby_3_3 from master (NixOS/nixpkgs#575425) and the Flox
# base catalog follows master, so the catalog's ruby_3_3 stays at 3.3.12.
# Delete this package when Ruby 3.3 reaches end of support (end of March
# 2027), or when the base catalog carries a ruby_3_3 at least this new.
#
# Built with nixpkgs' mkRuby rather than by overriding ruby_3_4: mkRuby
# derives the lib and gem directories, the soname and the setup hook from the
# version it is given, and overriding another series would leave them at 3.4.

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version;
  parts = builtins.splitVersion version;

  ruby = mkRuby {
    version =
      mkRubyVersion (builtins.elemAt parts 0) (builtins.elemAt parts 1) (builtins.elemAt parts 2)
        "";
    inherit (versionData) hash cargoHash;
  };
in
# jitSupport only gates nixpkgs' removal of the compiler from rbconfig.rb;
# Ruby 3.3's configure ignores the flag it maps to, and yjitSupport is a
# separate switch that stays on. Left on, clang and LLVM add ~750 MiB to the
# closure.
(ruby.override { jitSupport = false; }).overrideAttrs (old: {
  # mkRuby's version is an attrset that stringifies on demand, which Flox
  # rejects as a package version. `.version` is read from passthru.
  passthru = old.passthru // {
    inherit version;
  };

  installCheckPhase = old.installCheckPhase + ''
    $out/bin/ruby -e 'abort "wrong version: #{RUBY_VERSION}" unless RUBY_VERSION == "${version}"'
    # Extensions linked against the libraries in buildInputs.
    $out/bin/ruby -ropenssl -ryaml -rzlib -rreline -rfiddle -e 'puts "extensions ok"'
    $out/bin/gem --version
  '';
})
