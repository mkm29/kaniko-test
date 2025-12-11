#!/bin/bash

set -eo pipefail

trap 'rm -f config.json' EXIT

if [ -z "$DOCKER_HUB_USERNAME" ]; then
  read -rp "Docker Hub Username: " username
else
  username="$DOCKER_HUB_USERNAME"
fi

if [ -z "$DOCKER_HUB_KANIKO_PAT" ]; then
  read -rsp "Docker Hub Kaniko PAT: " password
else
  password="$DOCKER_HUB_KANIKO_PAT"
fi
echo

read -rp "Image Name [kaniko-nginx]: " image_name
image_name="${image_name:-kaniko-nginx}"
read -rp "Tag [current timestamp]: " tag
tag="${tag:-$(date +%Y%m%d%H%M%S)}"

cat > config.json <<EOF
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "$(echo -n "$username:$password" | base64)"
    }
  }
}
EOF

podman run --rm \
    --cap-drop=ALL \
    --cap-add=CHOWN \
    --cap-add=FOWNER \
    --cap-add=DAC_OVERRIDE \
    --security-opt=no-new-privileges \
    -v "$(pwd)/index.html:/tmp/workspace/index.html:ro" \
    -v "$(pwd)/dockerfile:/tmp/workspace/dockerfile:ro" \
    -v "$(pwd)/config.json:/kaniko/.docker/config.json:ro" \
    docker.io/smigula/kaniko-executor:latest \
    --context=/tmp/workspace \
    --dockerfile=dockerfile \
    --destination=docker.io/$username/$image_name:$tag