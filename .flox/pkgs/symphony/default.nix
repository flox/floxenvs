{
  lib,
  beam28Packages,
  fetchFromGitHub,
  makeWrapper,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version rev srcHash mixFodHash;

  beamPkgs = beam28Packages.extend (self: super: {
    elixir = super.elixir_1_19;
  });

  srcRoot = fetchFromGitHub {
    owner = "openai";
    repo = "symphony";
    inherit rev;
    hash = srcHash;
  };
in
beamPkgs.mixRelease {
  pname = "symphony";
  inherit version;
  src = "${srcRoot}/elixir";

  mixFodDeps = beamPkgs.fetchMixDeps {
    pname = "mix-deps-symphony";
    inherit version;
    src = "${srcRoot}/elixir";
    hash = mixFodHash;
  };

  nativeBuildInputs = [ makeWrapper ];

  # The mix release script is named after the OTP app
  # (`symphony_elixir`). Expose it as `symphony` for the
  # CLI experience promised in upstream docs.
  postInstall = ''
    if [ -e $out/bin/symphony_elixir ] \
        && [ ! -e $out/bin/symphony ]; then
      makeWrapper $out/bin/symphony_elixir \
        $out/bin/symphony \
        --set RELEASE_COOKIE symphony
    fi
  '';

  meta = {
    description = "OpenAI Symphony agent orchestrator";
    homepage = "https://github.com/openai/symphony";
    license = lib.licenses.asl20;
    mainProgram = "symphony";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
