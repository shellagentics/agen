---
prompt_id: build-agent-cli
version: 1.0.0
created_at: 2026-01-23
updated_at: 2026-01-23
author: human
status: active
model_target: claude-sonnet-4-20250514
tags: [system, build, specification]
---

# Building `agent`: A Unix-Native Agent CLI

## Condensed Build Prompt (v2)

---

## Part 1: Context

### Why We're Building This

The terminal is a 50-year-old prototype of an agentic interface. There are two visions:

**Vision A: Agent as Shell** — The agent is the orchestrator. Humans live inside the agent interface. (Claude Code, Cursor)

**Vision B: Agent in the Shell** — The agent is one tool among many. The shell orchestrates. Agents compose in pipelines.

```
# Vision B in action
cat error.log | agent "diagnose" | agent "suggest fix" > recommendations.md
```

**Vision B is underbuilt. That's the gap. That's what we're building.**

### Why Bash

1. Zero dependencies — runs anywhere
2. Forces simplicity — can't over-engineer
3. Feel the pain — before abstracting to Python/Elixir
4. Transparency — anyone can read the source in 5 minutes
5. Unix credibility — the tool embodies the philosophy it advocates

This is Phase 1 of a larger vision. Bash proves the interface contract. Later phases may reimplement in Elixir for the BEAM thesis.

---

## Part 2: The Interface Contract

This is the specification. Implementation serves this contract, not the reverse.

### Synopsis

```
agent [OPTIONS] [PROMPT]
command | agent [OPTIONS] [PROMPT]
```

### Options

```
--help              Show help message
--version           Show version
--batch             No interactive prompts; exit 2 if input needed
--json              Output JSON instead of plain text
--state=FILE        State file for persistence/resume
--resume            Continue from state file
--checkpoint        Save state after completion
--max-turns=N       Maximum agentic loop iterations (default: 1)
--tools=LIST        Tools to enable (default: none). Available: bash
--model=MODEL       Model to use (default: claude-sonnet-4-20250514)
--verbose           Debug output on stderr
```

### Exit Codes

| Code | Name | Meaning | Script Usage |
|------|------|---------|--------------|
| 0 | SUCCESS | Task completed | `agent && echo "done"` |
| 1 | FAILURE | Error occurred | `agent \|\| echo "failed"` |
| 2 | NEEDS_INPUT | Human input required (batch mode) | Retry with more context |
| 3 | LIMIT | Hit max-turns | Increase limit or checkpoint |

### State File Format

```json
{
  "version": "1",
  "created_at": "2026-01-22T10:30:00Z",
  "updated_at": "2026-01-22T10:35:00Z",
  "model": "claude-sonnet-4-20250514",
  "messages": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ],
  "tools_enabled": ["bash"],
  "turn_count": 3,
  "status": "completed"
}
```

---

## Part 3: Phase Overview

Each phase produces a tested commit. You can `git checkout` any phase.

| Phase | Name | What It Adds | Key Test |
|-------|------|--------------|----------|
| 0 | Interface Contract | `--help`, `--version` only | Help text displays |
| 1 | Basic Flow | stdin → LLM → stdout | `echo "hi" \| agent "respond"` works |
| 2 | Exit Semantics | `--batch`, exit codes 0/1/2 | Script can `case $?` |
| 3 | State | `--state`, `--resume` | Multi-turn conversation persists |
| 4 | Agentic Loop | `--tools=bash`, `--max-turns` | Agent creates a file |
| 5 | Checkpoint | `--checkpoint` with metadata | State includes timestamps |

---

## Part 4: Pattern Examples

These patterns establish the style and structure for implementation.

### Example 1: Script Header and Globals

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
DEFAULT_MODEL="claude-sonnet-4-20250514"

# Exit codes as named constants
EXIT_SUCCESS=0
EXIT_FAILURE=1
EXIT_NEEDS_INPUT=2
EXIT_LIMIT=3
```

**Why this pattern:**
- `set -euo pipefail` catches errors early
- Named constants make exit codes self-documenting
- Globals at top are easy to find and modify

### Example 2: Argument Parsing

```bash
# Initialize defaults
BATCH_MODE=false
VERBOSE=false
STATE_FILE=""
PROMPT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      show_help
      exit 0
      ;;
    --batch)
      BATCH_MODE=true
      shift
      ;;
    --state=*)
      STATE_FILE="${1#*=}"
      shift
      ;;
    --*)
      die "Unknown option: $1"
      ;;
    *)
      PROMPT="$1"
      shift
      ;;
  esac
done
```

**Why this pattern:**
- `--flag=value` parsed with `${1#*=}` (parameter expansion)
- Unknown flags fail fast with `die`
- Positional args collected last

### Example 3: Utility Functions

```bash
log() {
  if [[ "$VERBOSE" == true ]]; then
    echo "[agent] $*" >&2
  fi
}

die() {
  echo "agent: $*" >&2
  exit $EXIT_FAILURE
}

check_dependencies() {
  local missing=()
  command -v curl >/dev/null || missing+=(curl)
  command -v jq >/dev/null || missing+=(jq)

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing dependencies: ${missing[*]}"
  fi
}
```

**Why this pattern:**
- `log` respects `--verbose`, writes to stderr
- `die` centralizes error handling
- Dependency check runs once at start, fails fast

### Example 4: API Call with Error Handling

```bash
call_api() {
  local user_content="$1"

  local request_body
  request_body=$(jq -n \
    --arg model "$MODEL" \
    --arg content "$user_content" \
    '{model: $model, max_tokens: 4096, messages: [{role: "user", content: $content}]}')

  local response
  response=$(curl -s "https://api.anthropic.com/v1/messages" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$request_body")

  # Check for API error
  if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    die "API error: $(echo "$response" | jq -r '.error.message')"
  fi

  echo "$response" | jq -r '.content[0].text'
}
```

**Why this pattern:**
- `jq -n` builds JSON safely (no escaping issues)
- Error check before extracting content
- Returns just the text, not the full response

### Example 5: Test Harness

```bash
TESTS_RUN=0
TESTS_PASSED=0

test_case() {
  local name="$1"
  local expected_exit="$2"
  shift 2

  TESTS_RUN=$((TESTS_RUN + 1))

  set +e
  "$@" >/dev/null 2>&1
  local actual_exit=$?
  set -e

  if [[ $actual_exit -eq $expected_exit ]]; then
    echo "✓ $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "✗ $name (expected $expected_exit, got $actual_exit)"
  fi
}

# Usage
test_case "--help exits 0" 0 ./agent --help
test_case "missing API key exits 1" 1 env -u ANTHROPIC_API_KEY ./agent "test"
```

**Why this pattern:**
- `set +e` / `set -e` lets us capture exit codes
- Count passed/failed for summary
- Each test is one line, easy to scan

---

## Part 5: Phase Specifications

### Phase 0: Interface Contract

**Goal:** Define the interface before any implementation.

**Deliverables:**
- `agent` script with only `--help` and `--version` working
- `README.md` with usage examples
- `test.sh` that verifies help/version
- `DEVLOG.md` for notes

**Tests to pass:**
```bash
./agent --help        # exits 0, output contains "SYNOPSIS"
./agent --version     # exits 0, output contains version number
./agent "anything"    # exits 1 (not yet implemented)
```

**Commit:** `"Phase 0: Define agent CLI interface contract"`

---

### Phase 1: Basic Flow

**Goal:** stdin + prompt → LLM → stdout

**Behavior:**
- If stdin has content, read it
- Combine stdin + prompt argument into user message
- Call Anthropic API
- Output response to stdout

**Tests to pass:**
```bash
./agent "Say hello"                    # exits 0, outputs response
echo "2+2" | ./agent "What is this?"   # exits 0, outputs response
./agent                                # exits 1 (no prompt)
env -u ANTHROPIC_API_KEY ./agent "x"   # exits 1 (no API key)
```

**Commit:** `"Phase 1: Basic stdin→LLM→stdout flow"`

---

### Phase 2: Exit Semantics

**Goal:** Proper exit codes for scripting.

**Behavior:**
- `--batch` flag disables any interactive behavior
- Exit 0 on success
- Exit 1 on error
- Exit 2 if response appears to need clarification (batch mode only)

**Needs-input heuristic (simplification):**
```bash
# If response is short and ends with "?" or contains clarification phrases
# This is imperfect but useful for demos
```

**Tests to pass:**
```bash
./agent "Say exactly: hello"           # exits 0
./agent --batch "Say exactly: hello"   # exits 0
# Testing exit 2 is tricky - see notes below
```

**Note:** The "needs input" detection is a heuristic. Document its limitations in DEVLOG.md.

**Commit:** `"Phase 2: Add --batch mode and exit code semantics"`

---

### Phase 3: State Persistence

**Goal:** Multi-turn conversations via state file.

**Behavior:**
- `--state=FILE` enables stateful mode
- Without `--resume`: start new conversation, save to file
- With `--resume`: load existing state, append new turn, save
- State file is JSON (see format in Part 2)

**Tests to pass:**
```bash
./agent --state=test.json "First message"     # creates test.json
./agent --state=test.json --resume "Second"   # appends to test.json
jq '.messages | length' test.json             # outputs 4 (2 user + 2 assistant)
./agent --state=nonexistent --resume "x"      # exits 1 (file not found)
```

**Commit:** `"Phase 3: Add state persistence and --resume"`

---

### Phase 4: Agentic Loop

**Goal:** Agent can use tools and loop until task complete.

**Behavior:**
- `--tools=bash` enables bash tool
- `--max-turns=N` limits iterations (default 1)
- Agent loop: call API → check for tool use → execute tool → feed result back → repeat
- Exit 3 if max turns reached without completion

**Simplification note:**
The Anthropic API has native tool use support. For this bash POC, we use a simpler approach: instruct the model via system prompt to output tool calls in a parseable format. This is fragile but demonstrates the pattern. A production implementation would use the native tool API.

**Tests to pass:**
```bash
./agent --tools=bash "Create /tmp/agent-test.txt with 'hello'"  # file exists after
./agent --tools=bash --max-turns=1 "List files then count them" # may exit 3
```

**Commit:** `"Phase 4: Add agentic loop with bash tool"`

---

### Phase 5: Checkpoint

**Goal:** Explicit checkpointing with full metadata.

**Behavior:**
- `--checkpoint` explicitly saves state after completion
- State includes: version, timestamps, model, messages, tools, status
- Without `--checkpoint`, stateful conversations still save (for continuity)

**Tests to pass:**
```bash
./agent --state=cp.json --checkpoint "Test"
jq '.status, .updated_at' cp.json             # both fields present
```

**Commit:** `"Phase 5: Formalize checkpoint with full state metadata"`

---

## Part 6: Common Mistakes

### Mistake 1: Parsing JSON with grep/sed

```bash
# ❌ BAD: Fragile, breaks on whitespace/formatting
response=$(echo "$json" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)

# ✅ GOOD: Use jq
response=$(echo "$json" | jq -r '.content[0].text')
```

### Mistake 2: Forgetting to quote variables

```bash
# ❌ BAD: Word splitting breaks on spaces
if [[ $user_input == "" ]]; then

# ✅ GOOD: Always quote
if [[ "$user_input" == "" ]]; then
```

### Mistake 3: Not handling API errors

```bash
# ❌ BAD: Assumes success
response=$(curl -s "$URL" -d "$body")
echo "$response" | jq -r '.content[0].text'

# ✅ GOOD: Check for error first
response=$(curl -s "$URL" -d "$body")
if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
  die "API error: $(echo "$response" | jq -r '.error.message')"
fi
echo "$response" | jq -r '.content[0].text'
```

### Mistake 4: Ignoring exit codes in tests

```bash
# ❌ BAD: Test passes even if command fails
output=$(./agent "test")
echo "Test passed"

# ✅ GOOD: Check exit code
if output=$(./agent "test"); then
  echo "✓ Test passed"
else
  echo "✗ Test failed with exit code $?"
fi
```

### Mistake 5: Hardcoding paths

```bash
# ❌ BAD: Assumes current directory
source ./utils.sh

# ✅ GOOD: Relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
```

### Mistake 6: Not using `set -euo pipefail`

```bash
# ❌ BAD: Errors silently ignored
#!/bin/bash
undefined_var_typo  # continues running
failed_command      # continues running

# ✅ GOOD: Fails fast on errors
#!/usr/bin/env bash
set -euo pipefail
undefined_var_typo  # script exits
failed_command      # script exits
```

---

## Part 7: File Listing

After all phases, your directory contains:

```
agent/
├── agent              # The CLI (~300 lines bash)
├── test.sh            # Test suite
├── README.md          # User documentation
├── DEVLOG.md          # Your build notes
└── .git/              # One commit per phase
```

---

## Part 8: Quick Reference Card

```
USAGE
  agent [OPTIONS] [PROMPT]
  command | agent [OPTIONS] [PROMPT]

EXIT CODES
  0 = success    1 = failure    2 = needs input    3 = hit limit

KEY PATTERNS
  Stateless:     cat log | agent "diagnose"
  Stateful:      agent --state=s.json "start" → agent --state=s.json --resume "continue"
  Agentic:       agent --tools=bash --max-turns=5 "do complex task"
  Scripted:      cat data | agent --batch && echo "ok" || echo "failed: $?"

DEPENDENCIES
  bash 4+, curl, jq, ANTHROPIC_API_KEY env var
```

---

## Summary

This prompt provides:

1. **Context** — Why Vision B, why bash
2. **Contract** — The interface specification (options, exit codes, state format)
3. **Phases** — What to build in what order
4. **Patterns** — Labeled examples of key idioms
5. **Specs** — Per-phase requirements and tests
6. **Antipatterns** — What not to do

The implementation details are intentionally sparse. The goal is to guide structure and style while leaving room for you to solve the problems and learn from the friction.

Build phase by phase. Have user test before committing. Have user update DEVLOG.md as they go.

This prompt should be saved as an artifact and version controlled.

---

## Changelog

### v1.0.0 (2026-01-23)
- Initial version of build prompt
- Defines 6 phases (0-5) for incremental implementation
- Establishes bash coding patterns and antipatterns
- Specifies interface contract with exit codes and state format
