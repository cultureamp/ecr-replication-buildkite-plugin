#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"

  # Uncomment to enable stub debugging
  # export AWS_STUB_DEBUG=/dev/tty
}

@test "Fails when image-name not provided" {
  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "Missing required parameter: 'image-name'"
}

@test "Successfully waits for replication when all regions are complete" {
  export BUILDKITE_PLUGIN_ECR_REPLICATION_IMAGE_NAME="123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"

  stub aws \
    'ecr describe-image-replication-status --repository-name my-repo --image-id imageTag=latest --output json : echo "{\"replicationStatuses\":[{\"status\":\"COMPLETE\",\"region\":\"us-east-1\"},{\"status\":\"COMPLETE\",\"region\":\"us-west-2\"}]}"'

  stub jq \
    '-r .replicationStatuses[].status : echo -e "COMPLETE\nCOMPLETE"'

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "Monitoring ECR replication for image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"
  assert_output --partial "replication status: 2 complete, 0 in progress, 0 failed (2 total regions)"
  assert_output --partial "✅ All regions have completed replication successfully"

  unstub aws
  unstub jq
}

@test "Waits and retries when replication is in progress" {
  export BUILDKITE_PLUGIN_ECR_REPLICATION_IMAGE_NAME="123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:v1.0.0"

  stub aws \
    'ecr describe-image-replication-status --repository-name my-repo --image-id imageTag=v1.0.0 --output json : echo "{\"replicationStatuses\":[{\"status\":\"IN_PROGRESS\",\"region\":\"us-east-1\"},{\"status\":\"COMPLETE\",\"region\":\"us-west-2\"}]}"' \
    'ecr describe-image-replication-status --repository-name my-repo --image-id imageTag=v1.0.0 --output json : echo "{\"replicationStatuses\":[{\"status\":\"COMPLETE\",\"region\":\"us-east-1\"},{\"status\":\"COMPLETE\",\"region\":\"us-west-2\"}]}"'

  stub jq \
    '-r .replicationStatuses[].status : echo -e "IN_PROGRESS\nCOMPLETE"' \
    '-r .replicationStatuses[].status : echo -e "COMPLETE\nCOMPLETE"'

  stub sleep \
    '2 : echo "sleeping 2s"'

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "replication status: 1 complete, 1 in progress, 0 failed (2 total regions)"
  assert_output --partial "Waiting 2s before next check..."
  assert_output --partial "replication status: 2 complete, 0 in progress, 0 failed (2 total regions)"
  assert_output --partial "✅ All regions have completed replication successfully"

  unstub aws
  unstub jq
  unstub sleep
}

@test "Fails when AWS CLI returns error" {
  export BUILDKITE_PLUGIN_ECR_REPLICATION_IMAGE_NAME="123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"

  stub aws \
    'ecr describe-image-replication-status --repository-name my-repo --image-id imageTag=latest --output json : exit 1'

  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "Failed to describe image replication status"

  unstub aws
}

@test "Fails when no replication statuses found" {
  export BUILDKITE_PLUGIN_ECR_REPLICATION_IMAGE_NAME="123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"

  stub aws \
    'ecr describe-image-replication-status --repository-name my-repo --image-id imageTag=latest --output json : echo "{\"replicationStatuses\":[]}"'

  stub jq \
    '-r .replicationStatuses[].status : echo ""'

  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "No replication statuses found for image my-repo:latest"

  unstub aws
  unstub jq
}

@test "Handles complex repository names with slashes" {
  export BUILDKITE_PLUGIN_ECR_REPLICATION_IMAGE_NAME="123456789012.dkr.ecr.us-east-1.amazonaws.com/my-org/my-service:v2.1.0"

  stub aws \
    'ecr describe-image-replication-status --repository-name my-org/my-service --image-id imageTag=v2.1.0 --output json : echo "{\"replicationStatuses\":[{\"status\":\"COMPLETE\",\"region\":\"us-east-1\"}]}"'

  stub jq \
    '-r .replicationStatuses[].status : echo "COMPLETE"'

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "Monitoring ECR replication for image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-org/my-service:v2.1.0"
  assert_output --partial "✅ All regions have completed replication successfully"

  unstub aws
  unstub jq
}

@test "Handles mixed status with failed regions" {
  export BUILDKITE_PLUGIN_ECR_REPLICATION_IMAGE_NAME="123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"

  stub aws \
    'ecr describe-image-replication-status --repository-name my-repo --image-id imageTag=latest --output json : echo "{\"replicationStatuses\":[{\"status\":\"COMPLETE\",\"region\":\"us-east-1\"},{\"status\":\"FAILED\",\"region\":\"us-west-2\"},{\"status\":\"COMPLETE\",\"region\":\"eu-west-1\"}]}"'

  stub jq \
    '-r .replicationStatuses[].status : echo -e "COMPLETE\nFAILED\nCOMPLETE"'

  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "replication status: 2 complete, 0 in progress, 1 failed (3 total regions)"
  assert_output --partial "Replication finished with 1 failed region(s) out of 3 total"

  unstub aws
  unstub jq
}

@test "Waits for in progress then handles failed status" {
  export BUILDKITE_PLUGIN_ECR_REPLICATION_IMAGE_NAME="123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"

  stub aws \
    'ecr describe-image-replication-status --repository-name my-repo --image-id imageTag=latest --output json : echo "{\"replicationStatuses\":[{\"status\":\"COMPLETE\",\"region\":\"us-east-1\"},{\"status\":\"IN_PROGRESS\",\"region\":\"us-west-2\"}]}"' \
    'ecr describe-image-replication-status --repository-name my-repo --image-id imageTag=latest --output json : echo "{\"replicationStatuses\":[{\"status\":\"COMPLETE\",\"region\":\"us-east-1\"},{\"status\":\"FAILED\",\"region\":\"us-west-2\"}]}"'

  stub jq \
    '-r .replicationStatuses[].status : echo -e "COMPLETE\nIN_PROGRESS"' \
    '-r .replicationStatuses[].status : echo -e "COMPLETE\nFAILED"'

  stub sleep \
    '2 : echo "sleeping 2s"'

  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "replication status: 1 complete, 1 in progress, 0 failed (2 total regions)"
  assert_output --partial "Waiting 2s before next check..."
  assert_output --partial "replication status: 1 complete, 0 in progress, 1 failed (2 total regions)"
  assert_output --partial "Replication finished with 1 failed region(s) out of 2 total"

  unstub aws
  unstub jq
  unstub sleep
}
