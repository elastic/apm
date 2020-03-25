#!/usr/bin/env bash

set -uexo pipefail

readonly APM_AGENT=${1}

echo "Sending PR to apm-$APM_AGENT-agent"