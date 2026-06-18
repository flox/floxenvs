{
  writeShellApplication,
  coreutils,
}:
writeShellApplication {
  name = "flox-agent-layout";
  runtimeInputs = [ coreutils ];
  text = builtins.readFile ./flox-agent-layout.sh;
}
