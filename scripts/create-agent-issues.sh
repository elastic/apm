#!/bin/bash

set -e

usage="$(basename "$0") -- program to create issues on one or multiple agent repos

Requires gh (https://github.com/cli/cli) to be installed.

    -h                  show this help text
    --all-agents        create issues for all agents
    --backend-agents    create issues for all backend agents
    -a, --agent         create issues for a specific agent (repeatable)
    -s, --spec-pr       the PR number of the spec PR that should be implemented by agents (required)
                        this determines the title and body of the created issues
    -m, --milestone     the milestone of the issue (optional)
    -d, --dry-run       perform a dry run
    "

dry_run=false
AGENTS=()
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --all-agents) AGENTS=(dotnet go java nodejs php python ruby rum-js); ;;
    --backend-agents) AGENTS=(dotnet go java nodejs php python ruby); ;;
    -a|--agent) AGENTS+=("$2"); shift ;;
    -s|--spec-pr) spec_pr="$2" ; shift ;;
    -m|--milestone) milestone="$2"; shift ;;
    -d|--dry-run) dry_run=true ;;
    -h|--help) echo "$usage" >&2; exit ;;
    *) echo "Unknown parameter passed: $1"; echo "$usage" >&2; exit 1 ;;
  esac
  shift || true
done

: "${AGENTS:?Variable not set or empty}"
: "${spec_pr:?Variable not set or empty}"

title=$(gh pr view ${spec_pr} -R elastic/apm | head -n 1 | cut -f2)
body="Implementing elastic/apm#${spec_pr}"

if [ -z "$milestone" ]; then
  milestone_cmd=''
else
  milestone_cmd="--milestone $milestone"
fi

TABLE_ROWS=()
for agent in "${AGENTS[@]}" ; do
  echo gh issue create -R elastic/apm-agent-$agent --title "$title" --body "$body" $milestone_cmd
  if [ "$dry_run" = false ] ; then
    issue=$(gh issue create -R elastic/apm-agent-$agent --title "$title" --body "$body" $milestone_cmd)
    TABLE_ROWS+=("| $agent | $milestone | $issue |")
  fi
done

echo "
Add this table to the issue description of https://github.com/elastic/apm/pull/${spec_pr}

| Agent   | Milestone | Link to agent implementation issue |
|---------|-----------|------------------------------------|"

for row in "${TABLE_ROWS[@]}" ; do
    echo $row
done
