# ECR Replication Buildkite Plugin

Waits for ECR image replication to complete across all regions before proceeding with the build step.

This plugin monitors the replication status of a Docker image in Amazon ECR and waits until the image has been successfully replicated to all configured regions. It uses exponential backoff (starting at 2 seconds, maximum 15 seconds) to efficiently poll the replication status.

## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - command: echo "Image replication complete"
    plugins:
      - cultureamp/ecr-replication#v1.0.0:
          image-name: "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"
```

## Configuration

### `image-name` (Required, string)

The name of the container image in ECR. This should be the same string that is supplied as an argument to the docker push command used to push the image to AWS ECR. 

It should have the form: `AWS_ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/REPOSITORY_NAME:IMAGE_TAG` with the text in capitals replaced with the appropriate values for your environment.

**Examples:**
- `123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:v1.0.0`
- `999999999999.dkr.ecr.eu-west-1.amazonaws.com/my-org/my-service:latest`

## Requirements

- AWS CLI must be installed and configured with appropriate permissions
- The image must already exist in ECR and have replication configured
- The plugin requires `jq` for JSON parsing

## How it works

1. The plugin extracts the repository name and image tag from the provided image name
2. It calls `aws ecr describe-image-replication-status` to check the current replication status
3. If not all regions show "COMPLETE" status, it waits and retries with exponential backoff
4. The plugin succeeds when all regions have completed replication

## Development

To run the tests:

```shell
docker-compose run --rm tests
```

To run the linter:

```shell
docker-compose run --rm lint
```

To run shellcheck:

```shell
docker-compose run --rm shellcheck
```

## License

MIT
