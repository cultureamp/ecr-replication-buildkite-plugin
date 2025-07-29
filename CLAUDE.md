# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Buildkite plugin that monitors ECR image replication status across AWS regions. The plugin waits for Docker images to complete replication before allowing pipeline steps to proceed.

## Development Commands

### Testing
- `docker-compose run --rm tests` - Run all BATS tests
- `docker-compose run --rm lint` - Run the Buildkite plugin linter
- `docker-compose run --rm shellcheck` - Run shellcheck on bash scripts

### Manual Testing
The plugin can be tested locally by setting environment variables and running the hook directly:
```bash
export BUILDKITE_PLUGIN_ECR_REPLICATION_IMAGE_NAME="123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"
./hooks/command
```

## Architecture

### Plugin Structure
- `plugin.yml` - Plugin metadata defining the `image-name` parameter
- `hooks/command` - Main execution script that runs on the `command` hook
- `lib/shared.bash` - Configuration helper with `plugin_read_config()` function
- `tests/command.bats` - BATS test suite with stubs for AWS CLI and jq

### Core Logic Flow
1. **Parameter Extraction**: `parse_image_name()` extracts repository name and tag from the full ECR image URI
2. **Replication Polling**: `wait_for_replication()` calls `aws ecr describe-image-replication-status` in a loop
3. **Exponential Backoff**: Starts at 2 seconds, doubles up to 15 seconds maximum wait time
4. **Status Evaluation**: Parses JSON response with `jq` and waits until all regions show "COMPLETE" status

### Environment Variables
Plugin parameters are accessed via environment variables with the prefix `BUILDKITE_PLUGIN_ECR_REPLICATION_`. The `plugin_read_config()` helper function handles this conversion automatically.

### Dependencies
- AWS CLI with ECR permissions
- jq for JSON parsing
- Image must already exist in ECR with replication configured

## Testing Strategy

Tests use BATS framework with stubbing:
- AWS CLI calls are stubbed to return controlled JSON responses
- jq calls are stubbed to return predictable status strings
- Tests cover parameter validation, success scenarios, retry logic, error handling, and complex repository names