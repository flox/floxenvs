{
  lib,
  beam28Packages,
  fetchFromGitHub,
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

  # upstream's mix.exs declares
  #   escript: [main_module: SymphonyElixir.CLI,
  #             name: "symphony", path: "bin/symphony"]
  # so the CLI users want is built by `mix escript.build`,
  # not by `mix release`. mixRelease handles escripts when
  # `escriptBinName` is set: it runs `mix escript.build`
  # instead of `mix release` and copies the named file to
  # $out/bin/, with erlang automatically added as a
  # runtime input.
  escriptBinName = "bin/symphony";

  mixFodDeps = beamPkgs.fetchMixDeps {
    pname = "mix-deps-symphony";
    inherit version;
    src = "${srcRoot}/elixir";
    hash = mixFodHash;
  };

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
