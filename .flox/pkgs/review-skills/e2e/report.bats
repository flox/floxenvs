#!/usr/bin/env bats

load test_helper/common

@test "report groups output under per-tool headers and names skill-tools" {
  good="$(fixture good-skill)"
  run review-skills report "$good"
  assert_success
  assert_output --partial "== skill-tools =="
  # the security scanner is always appended to the report surface
  assert_output --partial "== skillcheck =="
}

@test "report shows raw skill-tools output (not just the header)" {
  good="$(fixture good-skill)"
  run review-skills report "$good"
  assert_success
  # skill-tools emits a real score/report body; the header is not the only line
  [ "${#lines[@]}" -gt 2 ]
}

@test "report --json carries a tool array including skill-tools" {
  good="$(fixture good-skill)"
  run review-skills report --json "$good"
  assert_success
  echo "$output" | jq -e '. | type == "array"' >/dev/null
  echo "$output" | jq -e 'map(.tool) | index("skill-tools") != null' >/dev/null
}
