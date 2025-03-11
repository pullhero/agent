#!/usr/bin/env python3
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

import os
import json
import logging
import argparse
import requests
import sys
from github import Github
from gitingest import ingest
import pygit2

def setup_logging():
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )

def clone_repo_with_token(repo_url, local_path, github_token):
    """
    Clone the repository using the GITHUB_TOKEN for authentication with pygit2.
    """
    # Define the callback function for credentials (used by pygit2 for authentication)
    def credentials_callback(url, username_from_url, allowed_types):
        """
        Provide authentication credentials (username and password/token) for Git.
        """
        if github_token:
            return pygit2.UserPass("x-access-token", github_token)  # Use GitHub token for authentication
        else:
            raise ValueError("GITHUB_TOKEN is not set")

    try:
        # Perform the clone using pygit2 and pass the credentials callback for authentication
        logging.info(f"Cloning repository from {repo_url} to {local_path}")
        
        # Create a RemoteCallbacks object and pass it to pygit2
        remote_callbacks = pygit2.RemoteCallbacks(credentials=credentials_callback)
        
        # Set the callbacks to handle authentication
        pygit2.clone_repository(repo_url, local_path, callbacks=remote_callbacks)
        
        logging.info(f"Repository cloned to {local_path}")
    except Exception as e:
        logging.error(f"Error cloning the repository: {e}")
        raise

def get_pr_diff(github_token, owner, repo, pr_number):
    """Fetches the diff of a pull request."""
    url = f'https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}'
    headers = {
        'Authorization': f'Bearer {github_token}',
        'Accept': 'application/vnd.github.v3.diff'
    }
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.text

def call_ai_api(api_host, api_key, api_model, prompt):
    """Handles API calls with error handling."""
    url = f"https://{api_host}/v1/chat/completions"
    payload = {
        "model": api_model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 1000
    }
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()
    data = response.json()
    return data["choices"][0]["message"]["content"]

def main():
    setup_logging()
    parser = argparse.ArgumentParser(
        description='PullHero automatic PR reviews',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        epilog="Note: All API requests (for any provider) will use the endpoint '/v1/chat/completions'."
    )
    # GitHub specific parameters
    parser.add_argument('--github-token', default=os.environ.get('GITHUB_TOKEN'), help='GitHub Token')
    parser.add_argument('--event-path', default=os.environ.get('GITHUB_EVENT_PATH'), help='GitHub Event JSON Path')
    # LLM endpoint specific
    parser.add_argument('--api-key', default=os.environ.get('LLM_API_KEY'), help='AI API Key')
    parser.add_argument('--api-host', default=os.environ.get('LLM_API_HOST', 'api.openai.com'), help='LLM API HOST, like api.openai.com')
    parser.add_argument('--api-model', default=os.environ.get('LLM_API_MODEL', 'gpt-4-turbo'), help='LLM Model, like gpt-4-turbo')
    # New parameter: vote-action
    parser.add_argument('--vote-action', default=os.environ.get('VOTE_ACTION', 'comment'), help='Action to take for vote: "comment" (default) or "vote" (approve/request changes)')

    args = parser.parse_args()
    
    with open(args.event_path, 'r') as f:
        event = json.load(f)

    repo_name = os.environ['GITHUB_REPOSITORY']
    owner, repo = repo_name.split('/')

    if "pull_request" in event:
        pr_number = event["pull_request"]["number"]
    elif "issue" in event and "pull_request" in event["issue"]:
        pr_number = int(event["issue"]["pull_request"]["url"].split("/")[-1])
    else:
        logging.error("No valid pull request found in event payload.")
        sys.exit(1)
    
    logging.info(f"Processing PR #{pr_number}")
    
    diff = get_pr_diff(args.github_token, owner, repo, pr_number)

    local_repo_path = "/tmp/clone"
    repo_url = f"https://github.com/{owner}/{repo}.git"
    clone_repo_with_token(repo_url, local_repo_path, args.github_token)

    # Use the ingest method to get repository context (e.g., summary of code)
    summary, tree, content = ingest(f"{local_repo_path}")
    # TODO: When gitingest supports pulling private repos use the native method
    # summary, tree, content = ingest(f"https://github.com/{owner}/{repo}.git")
    
    prompt = f"""Code Review Task:
Begin Repository Content Section
{content}
End Repository Content Section

Begin PR Changes Diff Section
{diff}
End PR Changes Diff Section

Instructions:
1. Analyze exclusively the changes in the PR diff for quality, bugs, and best practices.
2. Provide concise feedback only for the diff using the Repository Content Section if needed.
3. End with "Vote: +1" (approve) or "Vote: -1" (request changes)."""
    
    try:
        review_text = call_ai_api(args.api_host, args.api_key, args.api_model, prompt)
    except Exception as e:
        logging.error(f"AI API call failed: {e}")
        sys.exit(1)
    
    vote = "+1" if "+1" in review_text else "-1" if "-1" in review_text else "0"
    
    provider_data = f"Provider: {args.api_host} Model: {args.api_model}"
    sourcerepo = "**[PullHero](https://github.com/ccamacho/pullhero)**"
    comment_text = (
        f"### [PullHero](https://github.com/ccamacho/pullhero) Review\n\n"
        f"**{provider_data}**\n\n{review_text}\n\n"
        f"**Vote**: {vote}\n\n{sourcerepo}"
    )
    
    g = Github(args.github_token)
    repo_obj = g.get_repo(f"{owner}/{repo}")
    pr_obj = repo_obj.get_pull(pr_number)

    if args.vote_action.lower() == "vote":
        if vote == "+1":
            pr_obj.create_review(body=comment_text, event="APPROVE")
            logging.info("Review created with event APPROVE")
        elif vote == "-1":
            pr_obj.create_review(body=comment_text, event="REQUEST_CHANGES")
            logging.info("Review created with event REQUEST_CHANGES")
        else:
            pr_obj.create_review(body=comment_text, event="COMMENT")
            logging.info("Review created with event COMMENT (neutral vote)")
    else:
        pr_obj.create_issue_comment(comment_text)
        logging.info("Review comment added using create_issue_comment")
    
    logging.info(f"Review completed with vote: {vote}")

if __name__ == "__main__":
    main()
