#!/usr/bin/env bash

set -uexo pipefail

readonly APM_AGENT=${1}
readonly APM_AGENT_SPECS_DIR=${2}
readonly DO_SEND_PR=${3:-"true"}
readonly APM_AGENT_REPO_NAME="apm-agent-${APM_AGENT}"
readonly GIT_DIR=".ci/git"
readonly APM_AGENT_REPO_DIR="${GIT_DIR}/${APM_AGENT_REPO_NAME}"

git clone "https://${GITHUB_TOKEN}@github.com/elastic/${APM_AGENT_REPO_NAME}" "${APM_AGENT_REPO_DIR}"

mkdir -p "${APM_AGENT_REPO_DIR}/${APM_AGENT_SPECS_DIR}"
echo "Copying feature files to the ${APM_AGENT_REPO_NAME} repo"
cp tests/agents/gherkin-specs/*.feature "${APM_AGENT_REPO_DIR}/${APM_AGENT_SPECS_DIR}"

cd ${APM_AGENT_REPO_DIR}
git checkout -b update-feature-files-$(date "+%Y%m%d%H%M%S")
git add ${APM_AGENT_SPECS_DIR}
git commit -m "test: synchronizing bdd specs"

if [[ "${DO_SEND_PR}" == "true" ]]; then
    hub pull-request -p --labels automation --reviewer @elastic/apm-agent-devs -m "test: synchronizing bdd specs"
else 
    echo "PR sent to ${APM_AGENT_REPO_NAME}"
fi
