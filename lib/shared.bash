#!/usr/bin/env bash

plugin_prefix="BUILDKITE_PLUGIN_ECR_REPLICATION_"

# Shorthand for reading env config
function plugin_read_config() {
  local var="${plugin_prefix}${1}"
  local default="${2:-}"
  echo "${!var:-${default}}"
}
