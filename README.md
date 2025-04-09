```markdown
# PullHero 🤖⚡

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-PullHero-blue.svg?logo=github&style=flat-square)](https://github.com/marketplace/actions/pullhero)

**AI-Powered Code Reviews**  
Automated code reviews with intelligent feedback and approval recommendations using state-of-the-art language models. PullHero aims to enhance the code review process by providing insightful analysis, suggestions, and efficient workflows for development teams.

## Features ✨

- 🧠 **Smart Code Analysis** - Deep context-aware reviews using DeepSeek or OpenAI.
- 📚 **Repository Understanding** - Code digest generation via [GitIngest](https://github.com/cyclotruc/gitingest).
- ✅ **Clear Voting System** - +1 (Approve) or -1 (Request Changes) recommendations.
- 🔌 **Multi-LLM Support** - Compatible with DeepSeek and OpenAI APIs (v1/chat/completions).
- 📝 **Detailed Feedback** - Actionable suggestions in PR comments.
- 🔒 **Secure Configuration** - Encrypted secret handling through GitHub.
- ⚡ **Fast Execution** - Optimized Python implementation.

## Quick Start 🚀

To get started with PullHero, follow these steps:

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

| Parameter       | Required | Default     | Description                               |
|----------------|----------|-------------|-------------------------------------------|
| `github-token`  | Yes      | -           | GitHub access token                       |
| `api-key`       | Yes      | -           | API key for LLM provider                  |
| `provider`      | No       | `openai`    | Either `deepseek` or `openai`             |
| `model`         | No       | `gpt-4-turbo` | Model name (e.g., `deepseek-chat-1.3`)    |
| `digest-length` | No       | `4096`      | Maximum characters for code digest        |
| `temperature`   | No       | `0.2`       | LLM creativity (0-2)                      |
| `max-feedback`  | No       | `1000`      | Maximum characters in feedback            |

### 4. Full Configuration Example

```yaml
uses: ccamacho/pullhero@v1
with:
  github-token: "${{ secrets.GITHUB_TOKEN }}"
  api-key: "${{ secrets.OPENAI_API_KEY }}"
  api-host: "api.openai.com"
  api-model: "gpt-4-turbo"
```

## Detailed Usage 📖

### Complete GitHub Action Using PullHero

To use PullHero, you can set it up to respond to issue comments:

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
