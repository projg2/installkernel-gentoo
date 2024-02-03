#!/usr/bin/env bash

set -e

IMAGE="installkernel-testing"

docker build -t ${IMAGE} .
docker run --privileged=true  --mount type=bind,source="$(pwd)",target=/tmp/installkernel-gentoo-9999,readonly -t ${IMAGE}
