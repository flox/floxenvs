{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  # The 754 skills ship ~1030 Python helpers (scripts/agent.py,
  # scripts/process.py, …) that import 90+ distinct third-party libs.
  # Most of that long tail is exotic or unpackaged (impacket, frida,
  # ghidra, yara, pwntools, …) and several fail to build on Darwin, so
  # bundling all of it would make the package un-buildable across the
  # four catalog systems. Instead we bundle a curated core: the
  # highest-frequency imports that build cleanly everywhere. Every
  # helper is wired to this interpreter regardless (see postInstall);
  # a skill that needs something outside the core pip-installs it per
  # slot, which the install note spells out.
  pythonEnv = python3.withPackages (ps: [
    ps.requests
    ps.urllib3
    ps.cryptography
    ps.pyyaml
    ps.rich
    ps.pandas
    ps.numpy
    ps.lxml
    ps.dnspython
    ps.boto3
    ps.botocore
    ps.paramiko
    ps.scapy
    ps.ldap3
    ps.jinja2
    ps.defusedxml
    ps.psutil
    ps.beautifulsoup4
    ps.pyjwt
    ps.jsonschema
  ]);
  py = "${pythonEnv}/bin/python3";

  src = fetchFromGitHub {
    owner = "mukul975";
    repo = "Anthropic-Cybersecurity-Skills";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-cybersecurity";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Each upstream skills/<name>/ is a self-contained directory skill
    # (SKILL.md plus optional scripts/, references/, assets/). Ship the
    # whole set, one directory per skill, into every agent skills dir we
    # support — exactly how flox/claude-code discovers them on PATH.
    for share in \
      "$out/share/claude-code/skills" \
      "$out/share/opencode/skills"; do
      mkdir -p "$share"
      cp -r "$src/skills"/. "$share/"
      chmod -R u+w "$share"
    done

    runHook postInstall
  '';

  # Two fix-ups so the packaged skills work without host assumptions:
  #
  #   1. Wire every Python helper to the bundled interpreter. The
  #      shebang is rewritten to ${py} (carries the curated core), and a
  #      re-exec shim is inserted as the first statement so that even
  #      when the agent launches a helper as `python scripts/agent.py`
  #      with some other Python, it re-launches under ${py} before any
  #      third-party import can fail. Helpers are made executable.
  #
  #   2. Upstream SKILL.md frontmatter puts `version:` at the top level,
  #      which the agentskills.io loader flags as an unknown key on every
  #      session start. With 754 skills that is a lot of warning noise,
  #      so nest it under `metadata:` (same fix as flox/skills-humanizer).
  postInstall = ''
    for share in \
      "$out/share/claude-code/skills" \
      "$out/share/opencode/skills"; do

      # 1. Self-contain the Python helpers.
      find "$share" -name '*.py' -type f | while read -r f; do
        awk -v py="${py}" '
          NR == 1 {
            has_sb = ($0 ~ /^#!/)
            print "#!" py
            print "import os as _os, sys as _sys"
            print "_PY = \"" py "\""
            print "if _os.path.realpath(_sys.executable) != _os.path.realpath(_PY) and _os.path.exists(_PY):"
            print "    _os.execv(_PY, [_PY] + _sys.argv)"
            if (!has_sb) print $0
            next
          }
          { print }
        ' "$f" > "$f.wired"
        mv "$f.wired" "$f"
        chmod +x "$f"
      done

      # 2. Nest the stray top-level `version:` frontmatter key.
      find "$share" -name 'SKILL*.md' -type f | while read -r md; do
        awk '
          BEGIN { fm = 0 }
          /^---[[:space:]]*$/ { fm++; print; next }
          fm == 1 && /^version:[[:space:]]/ {
            print "metadata:"
            print "  " $0
            next
          }
          { print }
        ' "$md" > "$md.new"
        mv "$md.new" "$md"
      done
    done
  '';

  meta = {
    description =
      "754 cybersecurity skills for Claude Code and OpenCode — web "
      + "security, pentesting, DFIR, threat intelligence, cloud "
      + "security, and malware analysis, mapped to MITRE ATT&CK, NIST "
      + "CSF 2.0, ATLAS, D3FEND, and NIST AI RMF. Python helpers ship "
      + "wired to a bundled interpreter carrying a curated core of "
      + "common libs (requests, cryptography, boto3, scapy, …).";
    homepage = "https://github.com/mukul975/Anthropic-Cybersecurity-Skills";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
