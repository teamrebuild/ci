#!/bin/sh

set -exo pipefail

if [ -z "$1" ]; then 
    echo "Please provide the mayastor git path!"
    exit 1
fi
MAYASTOR="$1"

# Docker config
DOCKER_REPO="teamrebuild"
DOCKER_IMAGE="ci"
DOCKER_TAG="latest"
DOCKER_CI=`mktemp -d`
trap 'rm -rf $DOCKER_CI' EXIT

echo "Building CI Docker image from $MAYASTOR into $DOCKER_CI"
pushd $MAYASTOR

# js tests modules that need to be prebuilt
mkdir -p $DOCKER_CI/mayastor-test
cp ./mayastor-test/*.json $DOCKER_CI/mayastor-test

# nix config
cp shell.nix $DOCKER_CI
cp -r nix $DOCKER_CI

# cache cargo dependencies
cargo vendor > $DOCKER_CI/config
sed -i 's/^directory = \"vendor\"/directory = \"\/usr\/src\/app\/vendor\"/1' $DOCKER_CI/config
mv vendor $DOCKER_CI

# Build and push the Docker image
cd $DOCKER_CI

cat <<'END' > Dockerfile
FROM mayadata/ms-buildenv:latest
WORKDIR /usr/src/app

# nix
COPY shell.nix .
COPY nix ./nix

# js tests
COPY mayastor-test/*.json ./mayastor-test/
RUN nix-shell --run 'cd mayastor-test; npm install'

# rust
COPY vendor ./vendor
COPY config .
END

sudo docker build -t $DOCKER_REPO/$DOCKER_IMAGE:$DOCKER_TAG ./
sudo docker push $DOCKER_REPO/$DOCKER_IMAGE:$DOCKER_TAG

echo "Docker image pushed to: $DOCKER_REPO/$DOCKER_IMAGE:$DOCKER_TAG"
popd
