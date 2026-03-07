---
name: develop
description: TDD development workflow for Spirefall. Use when implementing features, fixing bugs, or working on tasks from the plan. Delegates to godot-developer with TDD discipline and task tracking, consulting game-designer for design decisions.
argument-hint: [task description, group name, or feature]
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet
---

# Spirefall TDD Development Workflow

You are orchestrating development on Spirefall. Delegate all implementation work to the **godot-developer** agent using strict TDD, track progress via tasks, and consult **game-designer** when design decisions arise.

Initial request: $ARGUMENTS

---

## Phase 1: Understand the Task

1. Read specific file if given or `docs/work/plan.md` and any files to find the relevant group/task
2. Read any referenced files to understand scope and acceptance criteria
3. Create a task list from the acceptance criteria / checklist items using **TaskCreate**
   - Each checklist item or acceptance criterion becomes its own task
   - Use clear subjects like "Implement X" or "Test Y"
   - Set `activeForm` for spinner display (e.g., "Implementing X")

---

## Phase 2: Design Consultation (if needed)

Before implementation, evaluate whether the task involves **gameplay design decisions**:

- Balance values (damage, costs, HP, scaling formulas)
- Wave composition or enemy behavior
- Economy tuning (gold rewards, interest rates, costs)
- UX flow or mode design
- New mechanics or interactions between systems

**If yes**: Launch a **game-designer** agent to get design guidance. Include the specific question and relevant context. Wait for the response before proceeding to implementation.

**If no**: Proceed directly to Phase 3.

### Mobile Work: Use Both godot-developer and mobile-developer

For tasks involving mobile UI/UX (touch input, responsive layouts, mobile sizing, gesture systems, mobile builds), invoke **mobile-developer** alongside **godot-developer**:

- **mobile-developer**: Owns mobile UX design decisions — touch target sizing, dp-aware scaling, gesture patterns, safe areas, mobile-specific interaction flows, Android/iOS export pipelines
- **godot-developer**: Owns Godot implementation — scene architecture, GDScript coding, engine features, tween/animation, ScrollContainer gotchas, node path management, performance

Launch both agents in parallel when the task spans both domains (e.g., "implement two-tier TowerInfoPanel" needs mobile-developer for the UX design and godot-developer for the Godot scene restructuring). Use mobile-developer's UX recommendations as input to godot-developer's implementation.

---

## Phase 3: Architecture Decision Record

Before writing any implementation code, the **godot-developer** agent MUST create an ADR (Architecture Decision Record) documenting the technical approach.

### ADR Requirements

1. **Template**: Use the MADR template at `docs/adr/TEMPLATE.md`
2. **Filename**: `docs/adr/{yyyyMMddHHmmss}-{kebab-case-title}.md` — timestamp is the current date/time when the ADR is created
3. **Status**: Set to `accepted` (since we're proceeding to implementation)
4. **Content requirements**:
   - **Context**: Why this change is needed (reference the plan task, testing notes, or user request)
   - **Decision Drivers**: What constraints or goals drive the approach
   - **Considered Options**: At least 2 options (even if one is "do nothing" or clearly inferior)
   - **Decision Outcome**: Which option was chosen and why
   - **Consequences**: Known trade-offs of the chosen approach
   - **Confirmation**: How we'll verify the decision was implemented correctly (tests, manual checks)

### When to create an ADR

- **Always** for new systems, architectural changes, or non-trivial modifications
- **Skip** for trivial bug fixes, typo corrections, or value-only changes (e.g., tweaking a constant)
- When in doubt, create one — it's lightweight documentation that helps future decisions

### Workflow

1. Launch **godot-developer** with the task context and ask it to draft the ADR
2. Review the ADR for completeness
3. Write it to `docs/adr/` with the timestamp filename
4. Proceed to Phase 4 (TDD Implementation)

---

## Phase 4: TDD Implementation

For each task, launch a **godot-developer** agent with these explicit instructions:

### The TDD Contract (include in every godot-developer prompt)

> **You MUST follow strict TDD for this task. The workflow is:**
>
> 1. **RED** — Write a failing GdUnit4 test first that captures the expected behavior. Run the test suite to confirm it fails.
> 2. **GREEN** — Write the minimum production code to make the test pass. Run the test suite to confirm it passes.
> 3. **REFACTOR** — Clean up the code while keeping tests green. Run the test suite one final time.
>
> **Rules:**
>
> - Never write production code without a failing test first
> - Each test should be small and focused on one behavior
> - Run `./run_tests.sh` (or the appropriate test command) after each step to verify red/green status
> - If you find yourself writing code "just to make it work first", STOP — write the test first
> - Use existing test patterns from `tests/` as reference for structure and conventions
>
> **When done with each acceptance criterion:**
>
> - Confirm all tests pass
> - State which acceptance criterion is satisfied
> - List the test file(s) and production file(s) created/modified

### Task execution loop

For each task in the task list:

1. **Mark task as `in_progress`** via TaskUpdate
2. Launch **godot-developer** with:
   - The TDD contract above
   - The specific acceptance criterion / feature to implement
   - Any design guidance from game-designer (if applicable)
   - The ADR reference from Phase 3 (so the developer follows the documented approach)
   - Context about related files and existing code
3. When the agent completes:
   - Verify the acceptance criterion is met
   - **Mark task as `completed`** via TaskUpdate
4. Move to the next task

### When to consult game-designer mid-implementation

If the godot-developer encounters any of these during work, **pause and consult game-designer**:

- A balance value isn't specified in the GDD or plan
- The implementation reveals a design tension (e.g., two mechanics conflict)
- A gameplay feel question arises (e.g., "should this tower's projectile be homing?")
- The developer needs to choose between gameplay-affecting alternatives

---

## Phase 5: Wrap-up

After all tasks are complete:

1. Run the full test suite one final time to confirm everything passes
2. Verify no orphan nodes or test leaks
3. Update task list — all items should be `completed`
4. **Mark acceptance criteria as done in `docs/work/plan.md`** — change `- [ ]` to `- [x]` for each completed acceptance criterion in the relevant task(s)
5. Summarize what was built:
   - Features implemented
   - Tests added (count and file paths)
   - Files created/modified
   - Any design decisions made (with game-designer rationale)
   - Any follow-up items or tech debt noted
