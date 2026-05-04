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

  # Crush bumps go.mod's go directive faster than flox/nixpkgs ships
  # patch-level Go updates (e.g. requires 1.26.2 while we have 1.26.1).
  # Patch versions are binary compatible per Go 1 stability, so rewrite
  # the directive to whatever toolchain buildGo126Module provides.
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
