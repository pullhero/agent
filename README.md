# PullHero 🤖⚡

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-PullHero-blue.svg?logo=github&style=flat-square)](https://github.com/marketplace/actions/pullhero)

**AI-Powered Code Reviews**
Automated code reviews with intelligent feedback and approval
recommendations using state-of-the-art language models.

## Features ✨

- 🧠 **Smart Code Analysis** - Deep context-aware reviews using DeepSeek or OpenAI
- 📚 **Repository Understanding** - Code digest generation via [GitIngest](https://github.com/cyclotruc/gitingest)
- ✅ **Clear Voting System** - +1 (Approve) or -1 (Request Changes) recommendations
- 🔌 **Multi-LLM Support** - Compatible with DeepSeek and OpenAI APIs (v1/chat/completions)
- 📝 **Detailed Feedback** - Actionable suggestions in PR comments
- 🔒 **Secure Configuration** - Encrypted secret handling through GitHub
- ⚡ **Fast Execution** - Optimized Python implementation

## Quick Start 🚀

Any provider using the standard `/v1/chat/completions` endpoint should work.

### 1. Basic Setup

Add the following to your `.github/workflows/pullhero.yml`:

```yaml
name: PullHero Code Review
on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - name: Run code reviews
        uses: pullhero/agent@v1
        with:
          github-token: "${{ secrets.GITHUB_TOKEN }}"
          api-key: "${{ secrets.OPENAI_API_KEY }}"
          api-host: "api.openai.com"
          api-model: "gpt-4-turbo"
```

### 2. Configure Secrets

To securely configure PullHero, follow these steps:

1. Go to your repository on GitHub.
2. Navigate to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret**.
4. Add the following secrets:
   - **LLM_API_KEY**: Your DeepSeek or OpenAI API key.
   - **GITHUB_TOKEN**: This is automatically provided by GitHub (no action needed).

### 3. Configuration Options

#### Input Parameters

TODO:Fix the parameters

| Parameter       | Required | Default       | Description                            |
| --------------- | -------- | ------------- | -------------------------------------- |
| `github-token`  | Yes      | -             | GitHub access token                    |
| `api-key`       | Yes      | -             | API key for LLM provider               |
| `provider`      | No       | `openai`      | Either `deepseek` or `openai`          |
| `model`         | No       | `gpt-4-turbo` | Model name (e.g., `deepseek-chat-1.3`) |
| `digest-length` | No       | `4096`        | Maximum characters for code digest     |
| `temperature`   | No       | `0.2`         | LLM creativity (0-2)                   |
| `max-feedback`  | No       | `1000`        | Maximum characters in feedback         |

### Full Configuration Example

```yaml
uses: ccamacho/pullhero@v1
with:
  github-token: "${{ secrets.GITHUB_TOKEN }}"
  api-key: "${{ secrets.OPENAI_API_KEY }}"
  api-host: "api.openai.com"
  api-model: "gpt-4-turbo"
```

### Complete GitHub action using PullHero

```yaml
---
name: Pull Hero Code Review

on:
  issue_comment:
    types: [created]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read

    if: |
      github.event.issue.pull_request != null &&
      startsWith(github.event.comment.body, '/review')

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
        with:
          persist-credentials: false
          ref: ${{ github.event.issue.pull_request.head.ref }}
          repository: ${{ github.repository }}

      - name: Debug Comment Data
        run: |
          echo "Comment Details:"
          echo " - Comment Body: '${{ github.event.comment.body }}'"
          echo " - Comment Author: '${{ github.event.comment.user.login }}'"
          echo " - PR Number: ${{ github.event.issue.number }}"

      - name: Verify User Authorization
        id: check_user
        run: |
          COMMENT_USER="${{ github.event.comment.user.login }}"
          REPO="${{ github.repository }}"
          ORG="${REPO%%/*}"  # Extract organization/user name

          echo "Checking permissions for user: $COMMENT_USER in repo: $REPO"

          # Check if user is a repository collaborator
          COLLABORATOR_PERMS=$(curl -s -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
            "https://api.github.com/repos/$REPO/collaborators/$COMMENT_USER/permission")

          PERMISSION=$(echo "$COLLABORATOR_PERMS" | jq -r '.permission')

          if [[ "$PERMISSION" == "admin" || "$PERMISSION" == "write" ]]; then
            echo "User has write/admin access as a collaborator."
            echo "AUTHORIZED=true" >> $GITHUB_ENV
            exit 0
          fi

          # Check if user is an organization member
          ORG_PERMS=$(curl -s -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
            "https://api.github.com/orgs/$ORG/memberships/$COMMENT_USER")

          ORG_STATE=$(echo "$ORG_PERMS" | jq -r '.state')

          if [[ "$ORG_STATE" == "active" ]]; then
            echo "User is an active organization member."
            echo "AUTHORIZED=true" >> $GITHUB_ENV
            exit 0
          fi

          echo "User is NOT authorized to trigger the review."
          echo "AUTHORIZED=false" >> $GITHUB_ENV
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Exit if Unauthorized
        if: env.AUTHORIZED != 'true'
        run: |
          echo "ERROR: User is not authorized to trigger the review."
          exit 1

      - name: Debug Secret Variables
        run: |
          echo "Verifying Secret Variables..."

          if [[ -z "${{ secrets.OPENAI_API_KEY }}" ]]; then
            echo "ERROR: OPENAI_API_KEY is missing!"
          else
            echo "OPENAI_API_KEY is set. (Length: ${#OPENAI_API_KEY})"
          fi

          if [[ -z "${{ secrets.GITHUB_TOKEN }}" ]]; then
            echo "ERROR: GITHUB_TOKEN is missing!"
          else
            echo "GITHUB_TOKEN is set. (Length: ${#GITHUB_TOKEN})"
          fi
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Run PullHero
        uses: ccamacho/pullhero@v1
        with:
          github-token: "${{ secrets.GITHUB_TOKEN }}"
          api-key: "${{ secrets.OPENAI_API_KEY }}"
          api-host: "api.openai.com"
          api-model: "gpt-4-turbo"
```

## Security & Permissions 🔐

### Required Permissions

Ensure your workflow has the following permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

### Security Best Practices

- **Use Least-Privilege API Keys:** Restrict API keys to only necessary permissions.
- **Rotate Keys Regularly:** Update API keys periodically.
- **Monitor Usage:** Check usage logs on your LLM provider's dashboard.
- **Restrict Workflow Triggers:** Limit when the action runs:

```yaml
on:
  pull_request:
    paths:
      - "src/**"
      - "lib/**"
```

## Troubleshooting 🐞

### Common Issues

| Symptom            | Solution                                   |
| ------------------ | ------------------------------------------ |
| Missing API key    | Verify secret name matches workflow input  |
| Model not found    | Check provider/model compatibility         |
| Long processing    | Reduce `digest-length` value               |
| Truncated feedback | Increase `max-feedback` value              |
| Generic responses  | Adjust `temperature` (0.1-0.5 recommended) |

### Debugging

Add a debug step to your workflow:

```yaml
- name: Debug
  run: echo "Digest: $(cat digest.txt)"
```

## Development Contributions 👩‍💻

### Local Setup

- **Clone the repository:**

  ```bash
  git clone https://github.com/ccamacho/pullhero.git
  cd pullhero
  ```

- **Set up a Python virtual environment:**

  ```bash
  python -m venv .venv
  source .venv/bin/activate
  pip install -r requirements-dev.txt
  ```

### Release Process

Bump the version in `action.yml` and create a tagged release:

```bash
git tag -a v1.2.3 -m "Release notes"
git push origin --tags
```

**Maintained by [ccamacho](https://github.com/ccamacho)**
