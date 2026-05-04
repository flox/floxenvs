{
  lib,
  stdenv,
  buildGo126Module,
  fetchFromGitHub,
  installShellFiles,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash vendorHash;
in
buildGo126Module rec {
  pname = "crush";
  inherit version;

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit vendorHash;

  # WORKAROUND: crush bumps go.mod's `go` directive faster than
  # flox/nixpkgs ships patch-level Go updates. For example, v0.65.2
  # requires Go 1.26.2 but buildGo126Module currently provides 1.26.1.
  #
  # The directive is a minimum-version check enforced by Go's toolchain.
  # Nix builds run with GOTOOLCHAIN=local (the sandbox has no network),
  # so Go can't auto-fetch a newer toolchain and the build aborts:
  #
  #   go: go.mod requires go >= 1.26.2 (running go 1.26.1; GOTOOLCHAIN=local)
  #
  # Patch versions of Go are binary- and source-compatible (Go 1
  # stability guarantee), so rewriting the directive to match the
  # toolchain we have is safe. The substitution is dynamic so it keeps
  # working as crush bumps further (e.g. 1.26.3, 1.26.4, ...).
  #
  # Remove this once flox/nixpkgs catches up to whatever Go version
  # upstream's go.mod requires.
  postPatch = ''
    go_ver=$(go env GOVERSION | sed 's/^go//')
    sed -i "s/^go [0-9.]\+$/go $go_ver/" go.mod
  '';

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/charmbracelet/crush/internal/version.Version=${version}"
  ];

  nativeBuildInputs = [
    installShellFiles
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  postInstall =
    ''
      install -Dm644 schema.json $out/share/crush/schema.json
    ''
    + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd crush \
        --bash <($out/bin/crush completion bash) \
        --fish <($out/bin/crush completion fish) \
        --zsh <($out/bin/crush completion zsh)
    '';

  meta = {
    description = "Glamourous AI coding agent for your favourite terminal";
    homepage = "https://github.com/charmbracelet/crush";
    changelog = "https://github.com/charmbracelet/crush/releases/tag/v${version}";
    license = lib.licenses.fsl11Mit;
    maintainers = with lib.maintainers; [
      x123
      malik
      davinci42
    ];
    mainProgram = "crush";
  };
}
