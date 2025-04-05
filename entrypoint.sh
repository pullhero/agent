#!/bin/bash
set -e

# GNU GENERAL PUBLIC LICENSE
# Version 3, 29 June 2007
#
# Copyright (C) 2025 authors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Make sure .bashrc is sourced
. /root/.bashrc

echo "Run pullhero"

# Check if the event path exists
if [ ! -f "$VCS_EVENT_PATH" ]; then
  echo "Error: Event path not found: $VCS_EVENT_PATH"
  exit 1
fi

# Read the event data from the file
event_data=$(cat "$VCS_EVENT_PATH")

# Extract base and head branches using jq
base_branch=$(echo "$event_data" | jq -r '.pull_request.base.ref // "unknown"')
head_branch=$(echo "$event_data" | jq -r '.pull_request.head.ref // "unknown"')
repository=$(echo "$event_data" | jq -r '.repository.full_name // "unknown"')

# Determine if the change is a PR or Issue and get the PR number
change_type="unknown"
pr_number="none"

if echo "$event_data" | jq -e '.pull_request' > /dev/null; then
    change_type="pull_request"
    pr_number=$(echo "$event_data" | jq -r '.pull_request.number')
elif echo "$event_data" | jq -e '.issue' > /dev/null && echo "$event_data" | jq -e '.issue.pull_request' > /dev/null; then
    change_type="issue_with_pr"
    pr_number=$(echo "$event_data" | jq -r '.issue.pull_request.url' | awk -F'/' '{print $NF}')
elif echo "$event_data" | jq -e '.issue' > /dev/null; then
    change_type="issue"
fi

echo "Debugging Variables:"
echo "VCS_EVENT_PATH: $VCS_EVENT_PATH"
echo "VCS_EVENT_NAME: $VCS_EVENT_NAME"
echo "base_branch: $base_branch"
echo "head_branch: $head_branch"
echo "repository: $repository"
echo "change_type: $change_type"
echo "pr_number: $pr_number"
echo "VCS_TOKEN: $VCS_TOKEN"
echo "AGENT: $AGENT"
echo "AGENT_ACTION: $AGENT_ACTION"
echo "LLM_API_HOST: $LLM_API_HOST"
echo "LLM_API_KEY: $LLM_API_KEY"
echo "LLM_API_MODEL: $LLM_API_MODEL"

pullhero -v

pullhero --vcs-provider "github" \
         --vcs-token $VCS_TOKEN \
         --vcs-repository $repository \
         --vcs-change-id $pr_number \
         --vcs-change-type $change_type \
         --vcs-base-branch $base_branch \
         --vcs-head-branch $head_branch \
         --agent $AGENT \
         --agent-action $AGENT_ACTION \
         --llm-api-key $LLM_API_KEY \
         --llm-api-host $LLM_API_HOST \
         --llm-api-model $LLM_API_MODEL
