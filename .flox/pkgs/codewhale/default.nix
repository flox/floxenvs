{
  lib,
  stdenv,
  fetchFromGitHub,
  installShellFiles,
  rustPlatform,
  pkg-config,
  darwin,
  openssl,
  dbus,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash cargoHash;
in
rustPlatform.buildRustPackage {
  pname = "codewhale";
  inherit version;

  src = fetchFromGitHub {
    owner = "Hmbown";
    repo = "CodeWhale";
    tag = "v${version}";
    inherit hash;
  };

  inherit cargoHash;

  # Build only the user-facing binaries (`codewhale` dispatcher and the
  # `codewhale-tui` runtime). The workspace's default-members also pull in
  # `codewhale-app-server`, which is linked into the TUI crate, so we
  # don't need to build it as a separate binary.
  cargoBuildFlags = [
    "--package"
    "codewhale-cli"
    "--package"
    "codewhale-tui"
  ];

  # sigtool: crates/tui/build.rs compiles the macOS Computer Use helper
  # and then signs it by running `codesign` (build.rs:90), which is not on
  # PATH in the Darwin build sandbox — the build panicked with
  # "macOS builds require codesign to package Computer Use". sigtool
  # provides the codesign shim; an ad-hoc signature (identity "-") is what
  # build.rs asks for by default.
  nativeBuildInputs = [
    installShellFiles
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwin.sigtool ];

  buildInputs =
    [ openssl ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ dbus ];

  # sigtool's codesign implements only the ad-hoc signing subset: -s/--sign,
  # -i/--identifier, -f/--force and --entitlements. build.rs also passes
  # `--options runtime` and a `--timestamp*` flag, which it rejects
  # ("The following arguments were not expected"). Neither matters for the
  # ad-hoc signature (identity "-") this build produces: hardened runtime and
  # a timestamp are only meaningful for a real Developer ID. Drop those two
  # arguments so the helper still gets signed.
  # sigtool's codesign implements only the ad-hoc signing subset: -s/--sign,
  # -i/--identifier, -f/--force and --entitlements. crates/tui/build.rs also
  # passes `--options runtime` and a `--timestamp*` flag, which it rejects
  # ("The following arguments were not expected"). Neither matters for the
  # ad-hoc signature (identity "-") this build produces: hardened runtime and
  # a secure timestamp are only meaningful for a real Developer ID. Drop the
  # two arguments so the Computer Use helper still gets signed.
  postPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
    substituteInPlace crates/tui/build.rs \
      --replace-fail \
        $'            "--force",\n            if identity == "-" {\n                "--timestamp=none"\n            } else {\n                "--timestamp"\n            },\n            "--options",\n            "runtime",\n' \
        $'            "--force",\n'
  '';

  doCheck = false;

  # 0.9.11 ships a `#[cfg_attr(not(test), expect(dead_code))]` in
  # crates/tui/src/prompt_zones.rs that is unfulfilled with our rustc,
  # and upstream builds with `-D warnings`, turning that into a hard
  # error. Downgrade just that lint; drop when upstream fixes it.
  env.RUSTFLAGS = "-A unfulfilled_lint_expectations";

  postInstall = ''
    installShellCompletion --cmd codewhale \
      --bash <($out/bin/codewhale completion bash) \
      --fish <($out/bin/codewhale completion fish) \
      --zsh <($out/bin/codewhale completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Agentic coding terminal for open-source and open-weight models";
    homepage = "https://github.com/Hmbown/CodeWhale";
    changelog = "https://github.com/Hmbown/CodeWhale/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "codewhale";
    platforms = lib.platforms.unix;
  };
}
