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

event_data=$(cat "$VCS_EVENT_PATH")
event_type=$GITHUB_EVENT_NAME

# Initialize default values
base_branch="unknown"
head_branch="unknown"
repository=$(echo "$event_data" | jq -r '.repository.full_name // "unknown"')

case "$event_type" in
  "push")
    base_branch=$(echo "$event_data" | jq -r '.base_ref // empty')
    # base_ref is null unless pushing to a tag or in some forked workflows, so fallback to GITHUB_REF
    if [ -z "$base_branch" ]; then
      base_branch=${GITHUB_REF##*/}
    fi
    head_branch=${GITHUB_REF##*/}
    ;;

  "pull_request" | "pull_request_target")
    base_branch=$(echo "$event_data" | jq -r '.pull_request.base.ref // "unknown"')
    head_branch=$(echo "$event_data" | jq -r '.pull_request.head.ref // "unknown"')
    ;;

  "workflow_dispatch")
    base_branch=${GITHUB_REF##*/}
    head_branch="unknown"
    ;;

  "repository_dispatch")
    # If custom inputs were passed via client payload
    base_branch=$(echo "$event_data" | jq -r '.client_payload.base_branch // "unknown"')
    head_branch=$(echo "$event_data" | jq -r '.client_payload.head_branch // "unknown"')
    ;;

  "schedule")
    # Typically runs on default branch
    base_branch=${GITHUB_REF##*/}
    head_branch="unknown"
    ;;

  "release")
    base_branch=${GITHUB_REF##*/}
    head_branch=$(echo "$event_data" | jq -r '.release.tag_name // "unknown"')
    ;;

  "issue_comment")
    # Handle comments on PRs (which GitHub treats as issues)
    if [ "$(echo "$event_data" | jq -r '.issue.pull_request // empty')" != "" ]; then
      pr_url=$(echo "$event_data" | jq -r '.issue.pull_request.url')
      pr_data=$(curl -s -H "Authorization: token $VCS_TOKEN" "$pr_url")
      base_branch=$(echo "$pr_data" | jq -r '.base.ref // "unknown"')
      head_branch=$(echo "$pr_data" | jq -r '.head.ref // "unknown"')
    else
      # Regular issue comment (not on a PR)
      base_branch=${GITHUB_REF##*/}
      head_branch="unknown"
    fi
    ;;

  *)
    echo "Unsupported or unhandled event type: $event_type"
    ;;
esac

echo "Repository: $repository"
echo "Event Type: $event_type"
echo "Base Branch: $base_branch"
echo "Head Branch: $head_branch"

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
