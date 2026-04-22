#!/usr/bin/env bats

load test_helper/common

@test "version prints semver" {
  run claude-managed version
  assert_success
  assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "--version prints semver" {
  run claude-managed --version
  assert_success
  assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "no args prints usage and exits 1" {
  run claude-managed
  assert_failure
  assert_output --partial "Usage:"
}
