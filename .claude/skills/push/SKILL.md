---
name: push
description: Push committed changes to the remote. Checks for uncommitted work and prevents pushing to main.
  TRIGGER when: user asks to "push", "push changes", "push to remote", "git push", or any instruction implying pushing commits upstream.
  DO NOT TRIGGER when: user asks to commit, create a PR, or just check status.
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# Push Skill

Push committed changes to the remote repository.

## Workflow

### Step 1: Check Branch

Run `git branch --show-current`.

**If on `main`**: Warn the user that pushing directly to main is not recommended. Ask for explicit confirmation before proceeding. Do NOT push without their approval.

### Step 2: Check for Uncommitted Changes

Run `git status` to check for uncommitted or untracked files.

If there are any:
- List all uncommitted changes (staged, unstaged, and untracked) clearly
- Ask the user how to proceed:
  - Commit them first (offer to run the `/commit` skill)
  - Stash them
  - Push without them
- Wait for the user's response before continuing

### Step 3: Push

Run `git push -u origin <branch-name>`.

### Step 4: Confirm

Show the result — branch name, remote, and number of commits pushed (use `git log origin/<branch>..<branch> --oneline` before pushing to determine this, or note if the remote branch is new).
