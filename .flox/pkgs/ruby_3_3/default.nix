{
  lib,
  stdenv,
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

  # nixpkgs' jitSupport switch controls whether the compiler's store path is
  # stripped from rbconfig.rb and libruby. Ruby 3.3's configure ignores the
  # flag it maps to, and yjitSupport is a separate switch that stays on. The
  # two platforms want opposite settings:
  #
  # - macOS strips it. Left in, clang and LLVM add ~750 MiB to the closure,
  #   and the system library ABI is stable, so native gems build with the
  #   Apple toolchain the consumer already has.
  # - Linux keeps the compiler, by absolute path in rbconfig.rb (see the
  #   postInstall below). nixpkgs records only a bare `gcc` there, resolved
  #   from PATH, whatever jitSupport is, so a consumer's gems link with
  #   whichever gcc it supplies, and one built against an older glibc than
  #   this package's cannot link libruby (`cosh@GLIBC_2.44`). With the
  #   compiler named in rbconfig.rb and carried in the closure, consumers
  #   need no compiler of their own, only make.
  rubyForPlatform =
    if stdenv.hostPlatform.isDarwin then ruby.override { jitSupport = false; } else ruby;
in
rubyForPlatform.overrideAttrs (old: {
  # mkRuby's version is an attrset that stringifies on demand, which Flox
  # rejects as a package version. `.version` is read from passthru.
  passthru = old.passthru // {
    inherit version;
  };

  # Runs after nixpkgs' postInstall, which makes CC and CXX overridable from
  # the environment with the configured name as the default.
  postInstall =
    old.postInstall
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      sed -i "$rbConfig" \
        -e '/CONFIG\["CC"\]/ s|then "\([^"]*\)" else|then "${stdenv.cc}/bin/\1" else|' \
        -e '/CONFIG\["CXX"\]/ s|then "\([^"]*\)" else|then "${stdenv.cc}/bin/\1" else|'
    ''
    # configure keeps the newest -std flag the build's clang accepts (here
    # -std=gnu23), and rbconfig.rb derives CPP, LDSHARED and the rest from
    # CC. Apple clang 16 rejects that flag, so every gem build fails for a
    # consumer on Xcode 16.0. Without it clang uses its own default.
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      sed -i "$rbConfig" -e 's/ -std=[A-Za-z0-9+]*//g'
    '';

  installCheckPhase =
    # nixpkgs' own check requires rbconfig.rb's default CC to equal $CC, which
    # here is the compiler's absolute path rather than the bare `gcc` the
    # stdenv exports.
    lib.optionalString stdenv.hostPlatform.isLinux "export CC=${stdenv.cc}/bin/gcc\n"
    + old.installCheckPhase
    + ''
    $out/bin/ruby -e 'abort "wrong version: #{RUBY_VERSION}" unless RUBY_VERSION == "${version}"'
    # Extensions linked against the libraries in buildInputs.
    $out/bin/ruby -ropenssl -ryaml -rzlib -rreline -rfiddle -e 'puts "extensions ok"'
    $out/bin/gem --version

    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      # Consumers compile gems with whichever Apple clang they have, and older
      # releases reject the newest -std flag the build's compiler accepted.
      # CC, CXX and CPP are unset because rbconfig.rb returns them in place
      # of its recorded defaults when the build's stdenv exports them.
      env -u CC -u CXX -u CPP $out/bin/ruby -rrbconfig -e '
        bad = RbConfig::CONFIG.select { |_, v| v.to_s.include?("-std=") }
        abort "-std= flag in rbconfig.rb: #{bad.map { |k, v| "#{k}=#{v}" }.join(", ")}" unless bad.empty?
        puts "rbconfig.rb carries no -std= flag"'
    ''}
    # Build and load a native extension the way `gem install` does: mkmf
    # reads CC, LDSHARED and the link flags from this Ruby's rbconfig.rb and
    # links against its libruby.
    ext=$(mktemp -d)
    (
      cd "$ext"
      ${lib.optionalString stdenv.hostPlatform.isLinux ''
        # The build's stdenv puts gcc on PATH and exports CC, either of which
        # would compile the extension without rbconfig.rb naming a compiler.
        # Drop both so the compiler recorded there has to work.
        PATH=$(printf %s "$PATH" | tr : '\n' | grep -Ev -- '-(gcc|binutils)(-wrapper)?-[0-9]' | paste -sd: -)
        unset CC CXX CPP
        for tool in gcc cc c++ g++ ld; do
          if type -P "$tool" >/dev/null; then
            echo "$tool is still on PATH" >&2
            exit 1
          fi
        done
      ''}
      cat > extconf.rb <<'EOF'
    require "mkmf"
    abort "no native build toolchain" unless have_func("rb_str_new")
    create_makefile("native_check")
    EOF
      cat > native_check.c <<'EOF'
    #include <ruby.h>
    void Init_native_check(void) { rb_define_global_const("NATIVE_CHECK", INT2FIX(42)); }
    EOF
      $out/bin/ruby extconf.rb
      make
      $out/bin/ruby -I. -rnative_check -e 'abort "extension did not load" unless NATIVE_CHECK == 42; puts "native extension ok"'
    )
  '';
})
