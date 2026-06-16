#!/usr/bin/env bash
# =============================================================================
# Local build helper (for manual builds / testing)
# =============================================================================
# The automated multi-platform build and push to ghcr.io is handled by GitHub
# Actions (.github/workflows/docker-build.yml) and runs automatically on every
# push to main or when a version tag (v*) is pushed.
#
# Use this script only for local development / debugging.
# Prerequisites:
#   docker buildx ls
#   docker buildx create --name multiarch --driver docker-container --use
#   docker buildx inspect --bootstrap

VERSION=$(grep -oP '(?<=\bversion=")[^"]+' Dockerfile | head -1)
echo "Building version: ${VERSION}"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg CONTAINER_VERSION="${VERSION}" \
  -t "ghcr.io/dkuhnke/nextcloud-sync:${VERSION}" \
  -t "ghcr.io/dkuhnke/nextcloud-sync:latest" \
  --push \
  .

# docker buildx imagetools inspect ghcr.io/dkuhnke/nextcloud-sync:latest
