---
name: pr
description: Create a pull request from the current branch to main. Ensures all changes are committed first and prevents PRs from main.
  TRIGGER when: user asks to "create a pr", "open a pr", "make a pull request", "submit a pr", "push and pr", or any instruction implying creating a pull request.
  DO NOT TRIGGER when: user asks to just commit, push, or review code without creating a PR.
argument-hint: [optional PR title or description]
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# PR Skill

Create a pull request from the current branch to main.

## Workflow

### Step 1: Check Branch

Run `git branch --show-current` to get the current branch name.

**If on `main`**: Stop immediately and tell the user you cannot create a PR from main to main. Suggest they create a feature branch first.

### Step 2: Check for Uncommitted Changes

Run `git status` to check for uncommitted or untracked files.

If there are any:
- List all uncommitted changes (staged, unstaged, and untracked) clearly
- Ask the user how to proceed:
  - Commit them first (offer to run the `/commit` skill)
  - Stash them
  - Proceed without them

Wait for the user's response before continuing.

### Step 3: Push the Branch

Run `git push -u origin <branch-name>` to push the branch to the remote.

### Step 4: Create the PR

1. If `$ARGUMENTS` is provided, use it as the PR title
2. Otherwise, infer a clear title from the branch name and recent commits
3. Generate a concise PR body summarizing the changes (use `git log main..<branch> --oneline` for context)
4. Run `gh pr create --base main --title "<title>" --body "<body>"`

### Step 5: Confirm

Show the PR URL and a brief summary of what was included.
