#!/usr/bin/env bash

set -uexo pipefail

readonly APM_AGENT=${1}
readonly APM_AGENT_SPECS_DIR=${2}
readonly APM_AGENT_REPO_NAME="apm-agent-${APM_AGENT}"
readonly APM_AGENT_REPO_DIR=".ci/${APM_AGENT_REPO_NAME}"

git clone "https://github.com/elastic/${APM_AGENT_REPO_NAME}" "${APM_AGENT_REPO_DIR}"

mkdir -p "${APM_AGENT_REPO_DIR}/${APM_AGENT_SPECS_DIR}"
echo "Copying feature files to the ${APM_AGENT_REPO_NAME} repo"
cp tests/agents/gherkin-specs/*.feature "${APM_AGENT_REPO_DIR}/${APM_AGENT_SPECS_DIR}"

cd "${APM_AGENT_REPO_DIR}"
git checkout -b "update-feature-files-$(date "+%Y%m%d%H%M%S")"
git add "${APM_AGENT_SPECS_DIR}"
git commit -m "test: synchronizing bdd specs"
