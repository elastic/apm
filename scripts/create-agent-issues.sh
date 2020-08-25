#!/bin/bash

set -e

usage="$(basename "$0") -- program to create issues on one or multiple agent repos

Requires gh (https://github.com/cli/cli) to be installed.
Note that this clones all agent repos in the current directory the first time it's executed.

    -h              show this help text
    --all-agents    create issues for all agents
    -a, --agent     create issues for a specific agent (repeatable)
    -t, --title     the title of the issue (required)
    -b, --body      the body of the issue (required)
    -m, --milestone the milestone of the issue (required)
    -d, --dry-run   perform a dry run
    "

AGENTS=()
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --all-agents) AGENTS=(dotnet go java nodejs php python ruby rum-js); ;;
        -a|--agent) AGENTS+=("$2"); shift ;;
        -t|--title) title="$2"; shift ;;
        -b|--body) body="$2"; shift ;;
        -m|--milestone) milestone="$2"; shift ;;
	-d|--dry-run) dry_run=true ;;
	-h|--help) echo "$usage" >&2; exit ;;
        *) echo "Unknown parameter passed: $1"; echo "$usage" >&2; exit 1 ;;
    esac
    shift || true
done

: "${AGENTS:?Variable not set or empty}"
: "${title:?Variable not set or empty}"
: "${body:?Variable not set or empty}"

if [ -z "$milestone" ]; then
  MILESTONE_COMMAND=''
else
  MILESTONE_COMMAND="--milestone $milestone"
fi

for agent in "${AGENTS[@]}" ; do
  gh repo clone elastic/apm-agent-$agent || true
  pushd apm-agent-$agent
  if [ "$dry_run" = true ] ; then
    echo gh issue create --title "$title" --body "$body" $MILESTONE_COMMAND 
  else
    gh issue create --title "$title" --body "$body" $MILESTONE_COMMAND
  fi
  popd
done


