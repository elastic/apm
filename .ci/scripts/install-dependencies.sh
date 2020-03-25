#!/usr/bin/env bash

set -uexo pipefail

HOME=${HOME}
readonly HUB_VERSION="2.14.2"
readonly HUB_CMD="${HOME}/bin/hub"

# install GitHub's hub
curl -fsSL https://github.com/github/hub/raw/master/script/get | bash -s ${HUB_VERSION}
mkdir -p ${HUB_CMD}
mv bin/hub ${HUB_CMD}
