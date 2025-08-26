# docker buildx ls
# docker buildx create --name multiarch --driver docker-container --use
# docker buildx inspect --bootstrap
docker buildx build --platform linux/amd64,linux/arm64 -t dkuhnke/nextcloud-sync:2.7 -t dkuhnke/nextcloud-sync:latest --push .
# docker buildx imagetools inspect dkuhnke/nextcloud-sync:latest