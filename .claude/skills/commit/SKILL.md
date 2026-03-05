---
name: commit
description: Commit all changes with a well-crafted message. Reviews changes for safety and asks for confirmation on ambiguous items.
  TRIGGER when: user asks to "commit", "commit this", "commit changes", "save changes to git", "make a commit", or any instruction implying committing current work.
  DO NOT TRIGGER when: user asks to push, create a PR, or just check git status.
argument-hint: [optional commit message override]
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# Commit Skill

Commit all current changes with a clear, conventional commit message. Review changes for safety before committing.

## Workflow

### Step 1: Inspect Changes

Run `git status` and `git diff` (both staged and unstaged) to understand what has changed.

### Step 2: Classify Changes

Review every changed file and classify each as **safe** or **needs confirmation**:

**Safe changes** (commit without asking):
- Code changes that clearly match a single coherent intent
- Test files that correspond to changed production code
- Config changes that are obviously related to the other changes
- Documentation updates that describe the other changes

**Needs confirmation** (list and ask about):
- Unrelated changes that don't fit the main commit intent (e.g., a formatting fix mixed with a feature)
- Changes to sensitive files: CI/CD configs, deployment configs, dependency files (package.json, requirements.txt, etc.), environment files, secrets, or permission settings
- Large generated or binary file changes (images, compiled assets, lock files)
- Deletions of files that aren't obviously part of the current work
- Temporary or debug code (print statements, console.log, TODO/FIXME/HACK comments added)
- Changes to files outside the main project scope (dotfiles, IDE configs, unrelated subprojects)
- Any change whose purpose is unclear from context

### Step 3: Confirm with User

If there are changes that need confirmation, present them in a clear list:

```
These changes look safe to include:
- path/to/file1.gd — description of change
- path/to/file2.gd — description of change

These changes need your confirmation:
- path/to/debug.gd — contains new print() statements (debug code?)
- package.json — dependency version bumps (intentional?)
- .github/workflows/ci.yml — CI config change (unrelated to feature?)

Include all of these? Or should I exclude some?
```

Wait for the user's response before proceeding. If all changes are safe, skip this step.

### Step 4: Stage and Commit

1. Stage the approved files with `git add`
2. If `$ARGUMENTS` is provided, use it as the commit message
3. Otherwise, write a commit message following this format:
   - First line: concise summary in imperative mood (max 72 chars)
   - Blank line
   - Body: explain what changed and why (wrap at 72 chars), skip if the summary is self-explanatory
   - Add `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` trailer
4. Run `git commit`

### Step 5: Confirm

Show the commit hash and summary. Do NOT push unless explicitly asked.
