---
name: plan
description: Collaborative planning skill. Coordinates godot-developer, game-designer, and pixel-artist agents to create a detailed implementation plan from a given input. Overwrites docs/work/plan.md with the result (or a custom output path if specified).
  TRIGGER when: user asks to "create a plan", "make a plan", "plan this", "write an implementation plan", asks all three agents to collaborate on planning, or references creating/updating the work plan.
  DO NOT TRIGGER when: user asks to implement/develop/code a feature (use develop skill), asks a single agent a question, or is just reading/reviewing an existing plan.
argument-hint: [input] or [input] --output [path]
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet
---

# Spirefall Collaborative Planning Skill

You are orchestrating a **planning session** across three specialist agents to produce a comprehensive implementation plan.

Input: $ARGUMENTS

---

## Phase 0: Determine Output Path

Parse `$ARGUMENTS` to determine where the plan should be written:

- If the arguments contain `--output <path>` (or `-o <path>`), use that path as the output file. Remove the flag and path from the arguments before proceeding.
- Otherwise, default to `docs/work/plan.md`.

Store this as `OUTPUT_PATH` for use in Phase 4.

---

## Phase 1: Gather Context

1. **Read the input** — The user's argument (after stripping `--output` if present) may be:
   - A file path (e.g., a testing notes file, a feature spec, a bug list) — read it
   - A direct description of features/bugs/tasks — use as-is
   - A reference to a GDD section — find and read it from `docs/`
2. **Read existing project state** — Skim these to understand what's already built:
   - `docs/work/plan.md` (current plan, to understand completed vs pending work)
   - `CLAUDE.md` and `docs/GDD.md` if they exist (project conventions and design doc)
3. **Summarize the input** into a clear list of items to plan (bugs, features, improvements, polish tasks, etc.)

---

## Phase 2: Parallel Agent Consultation

Launch all three agents **in parallel**. Each agent receives the summarized input list and answers from their domain perspective.

### 2a: Game Designer Agent

Launch a **game-designer** agent with this prompt structure:

> You are being consulted for a planning session. Given the following input items, provide your **design analysis** for each:
>
> [paste summarized input list here]
>
> For each item, provide:
> - **Design assessment**: Is this a good idea? Does it align with the GDD? Any design concerns?
> - **Balance implications**: Will this affect game balance? How?
> - **Priority recommendation**: P0 (must-have), P1 (important), P2 (nice-to-have) — with rationale
> - **Design spec**: If the item requires design decisions (values, formulas, behaviors), specify them concretely
> - **Player experience impact**: How does this improve or change the player's experience?
>
> Also flag any **cross-item dependencies** or items that conflict with each other.
>
> Read any relevant project files you need for context (GDD, existing scripts, data files).

### 2b: Godot Developer Agent

Launch a **godot-developer** agent with this prompt structure:

> You are being consulted for a planning session. Given the following input items, provide your **technical analysis** for each:
>
> [paste summarized input list here]
>
> For each item, provide:
> - **Technical assessment**: How hard is this? What's the approach?
> - **Effort estimate**: Small (< 1 hour), Medium (1-3 hours), Large (3-8 hours)
> - **Files to create**: New files needed (scripts, scenes, resources, tests)
> - **Files to modify**: Existing files that need changes
> - **Implementation notes**: Key technical details, gotchas, Godot-specific considerations
> - **Test strategy**: What GdUnit4 tests are needed? How many roughly?
> - **Dependencies**: Which other items must be done first?
>
> Also identify any **architectural concerns** — does anything require refactoring existing systems?
>
> Read any relevant project files you need for context (existing scripts, scenes, autoloads).

### 2c: Pixel Artist Agent

Launch a **pixel-artist** agent with this prompt structure:

> You are being consulted for a planning session. Given the following input items, identify which ones have **visual/art implications** and provide your analysis:
>
> [paste summarized input list here]
>
> For items with visual needs, provide:
> - **Asset requirements**: What sprites, textures, UI elements, or VFX are needed?
> - **Specifications**: Dimensions, frame counts, color palettes, animation timing
> - **Art approach**: Programmatic generation vs placeholder vs final art
> - **Effort estimate**: Small / Medium / Large
> - **Visual design notes**: How it should look, readability concerns, element color consistency
>
> For items with NO visual implications, simply state "No art needed" and move on.
>
> Read any relevant project files for context (existing sprites, UI scenes, art assets).

---

## Phase 3: Synthesize the Plan

Once all three agents return, **synthesize their responses** into a single cohesive implementation plan.

### Plan Structure

Write the plan to `OUTPUT_PATH` using this exact structure:

```markdown
# [Plan Title Based on Input Scope]

**Goal:** [1-2 sentence summary of what this plan achieves]

**Reference:** [Source of the input — file path, user description, GDD section, etc.]

**Prerequisites:** [What must already be working before this plan starts]

---

## Architecture Overview

[High-level summary of new systems, modified systems, and how they fit together.
Use a code block diagram showing NEW SYSTEMS, NEW SCENES, MODIFIED FILES as appropriate.]

---

## Task Groups

### Group [Letter]: [Group Name] ([Priority])

[1-2 sentence description of what this group accomplishes]

---

#### Task [Letter][Number]: [Task Name]

**Priority:** [P0/P1/P2] | **Effort:** [Small/Medium/Large] | **GDD Ref:** [Section if applicable]

**New files:**
- [list of new files to create]

**Modified files:**
- [list of existing files to modify]

**Implementation notes:**
- [Technical details from godot-developer]
- [Design specs from game-designer]
- [Art specs from pixel-artist, if applicable]

**Acceptance criteria:**
- [ ] [Specific, testable criterion 1]
- [ ] [Specific, testable criterion 2]
- [ ] [etc.]

---

[Repeat for each task in the group]

[Repeat for each group]

---

## Dependency Graph

[ASCII diagram showing task dependencies, same style as existing plan.md]

---

## Recommended Implementation Order

[Table with columns: Order, Task, Group, Priority, Effort, Description]
[Organized into weekly milestones with milestone summaries]

---

## Summary

[Table with metrics: Total tasks, P0/P1/P2 counts, new files, modified files, etc.]

### Critical Path

[The minimum chain of tasks needed for the core deliverable]
```

### Synthesis Rules

- **Merge perspectives**: Each task should reflect all three agents' input where applicable
- **Resolve conflicts**: If agents disagree (e.g., designer says P0 but developer says it's huge effort), note the tension and make a judgment call with rationale
- **Group logically**: Cluster related tasks into groups (by system, by feature area, or by theme)
- **Order by dependency**: Tasks that others depend on come first within each group
- **Mark design decisions**: When the game-designer specified concrete values or behaviors, include them verbatim in implementation notes
- **Include art tasks**: If the pixel-artist identified asset needs, create dedicated art tasks or fold them into implementation tasks as sub-steps
- **Acceptance criteria must be testable**: Each criterion should be verifiable via a GdUnit4 test or a manual check

---

## Phase 4: Write the Plan

1. **Write the complete plan** to `OUTPUT_PATH` using the Write tool, replacing all existing content
2. **Verify** the plan is well-formed by reading it back
3. **Summarize** to the user:
   - Total task count and priority breakdown
   - Key design decisions made
   - Any unresolved questions or items that need user input
   - Suggested first task to start with
