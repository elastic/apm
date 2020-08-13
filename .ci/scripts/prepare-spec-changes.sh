#!/usr/bin/env bash

set -uexo pipefail

readonly APM_AGENT_REPO_NAME=${1}
readonly SPECS_TYPE=${2} # gherkin
readonly APM_AGENT_SPECS_DIR=${3}
readonly APM_AGENT_REPO_DIR=".ci/${APM_AGENT_REPO_NAME}"

EXTENSION="feature"

git clone "https://github.com/elastic/${APM_AGENT_REPO_NAME}" "${APM_AGENT_REPO_DIR}"

mkdir -p "${APM_AGENT_REPO_DIR}/${APM_AGENT_SPECS_DIR}"
echo "Copying spec files to the ${APM_AGENT_REPO_NAME} repo"
cp tests/agents/${SPECS_TYPE}-specs/*.${EXTENSION} "${APM_AGENT_REPO_DIR}/${APM_AGENT_SPECS_DIR}"

cd "${APM_AGENT_REPO_DIR}"
git checkout -b "update-spec-files-$(date "+%Y%m%d%H%M%S")"
git add "${APM_AGENT_SPECS_DIR}"
git commit -m "test: synchronizing ${SPECS_TYPE} specs"
