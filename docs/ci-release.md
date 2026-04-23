# CI And Release

## Purpose
This doc describes the minimal GitHub Actions setup for:
- backend and CMS verification on every push or pull request
- tagged image releases to `ECR`

It intentionally stays narrow:
- no deploy-from-CI yet
- no Flutter CI yet
- no preview environments

## Workflow Files
- [ci.yml](/Users/daniel.dev/Desktop/czech-go-system/.github/workflows/ci.yml)
- [release-images.yml](/Users/daniel.dev/Desktop/czech-go-system/.github/workflows/release-images.yml)

## CI Workflow
`ci.yml` runs on:
- `pull_request`
- pushes to `main`

It verifies:
- `go build ./...`
- `go test ./...`
- `npm run lint`
- `npm run build`

This keeps the main backend and CMS surfaces green without blocking on Flutter runner setup.

## Release Workflow
`release-images.yml` runs on tags matching:
- `v*`

Example:
- `v20260422-003`

The workflow:
1. reruns backend and CMS verification
2. configures AWS credentials through GitHub OIDC
3. logs into `ECR`
4. builds ARM64 backend and CMS images
5. pushes both images to `ECR`

The pushed image tag is the Git tag without the leading `v`.

Example:
- git tag `v20260422-003`
- image tag `20260422-003`

## Required GitHub Repository Variables
Set these in repository or organization variables:
- `AWS_REGION`
- `AWS_ACCOUNT_ID`
- `AWS_ROLE_TO_ASSUME`
- `ECR_BACKEND_REPOSITORY`
- `ECR_CMS_REPOSITORY`

Expected values:
- `AWS_ROLE_TO_ASSUME`
  Example: `arn:aws:iam::123456789012:role/github-actions-ecr-publisher`
- `ECR_BACKEND_REPOSITORY`
  Example: `czech-go-system-backend`
- `ECR_CMS_REPOSITORY`
  Example: `czech-go-system-cms`

## AWS IAM Shape
The assumed role should be allowed to:
- authenticate to `ECR`
- push images to the two target repositories

This workflow assumes GitHub OIDC instead of long-lived AWS access keys.

## Notes
- the release workflow uses Docker `buildx` plus `QEMU` so GitHub-hosted Linux runners can publish `linux/arm64` images for the production EC2 host
- deploy remains manual for now through the existing EC2 bundle and compose flow
