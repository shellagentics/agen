#!/usr/bin/env bash
set -euo pipefail

# Test harness for agen CLI
# Run: ./test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGEN="$SCRIPT_DIR/agen"

TESTS_RUN=0
TESTS_PASSED=0

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m' # No Color
else
  GREEN=''
  RED=''
  NC=''
fi

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
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name (expected $expected_exit, got $actual_exit)"
  fi
}

test_output_contains() {
  local name="$1"
  local pattern="$2"
  shift 2

  TESTS_RUN=$((TESTS_RUN + 1))

  set +e
  local output
  output=$("$@" 2>&1)
  set -e

  if echo "$output" | grep -q "$pattern"; then
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name (output does not contain '$pattern')"
  fi
}

echo "Running agen CLI tests..."
echo ""

# Phase 0 tests
echo "=== Phase 0: Interface Contract ==="

test_case "--help exits 0" 0 "$AGEN" --help
test_output_contains "--help contains SYNOPSIS" "SYNOPSIS" "$AGEN" --help
test_output_contains "--help contains OPTIONS" "OPTIONS" "$AGEN" --help

test_case "--version exits 0" 0 "$AGEN" --version
test_output_contains "--version contains version number" "0.3.0" "$AGEN" --version

test_case "no arguments exits 1" 1 "$AGEN"
test_case "unknown option exits 1" 1 "$AGEN" --unknown-flag

echo ""
echo "=== Stub Backend ==="

# Use a temp file for the stub counter so tests don't interfere with anything
STUB_COUNTER_FILE=$(mktemp)
rm -f "$STUB_COUNTER_FILE"
export AGEN_STUB_FILE="$STUB_COUNTER_FILE"

# First call should return 1
test_output_contains "stub returns 'LLM return 1' on first call" "LLM return 1" \
  env AGEN_BACKEND=stub "$AGEN" "test prompt"

# Second call should return 2 (counter increments)
test_output_contains "stub counter increments to 2" "LLM return 2" \
  env AGEN_BACKEND=stub "$AGEN" "test prompt"

# Third call should return 3
test_output_contains "stub counter increments to 3" "LLM return 3" \
  env AGEN_BACKEND=stub "$AGEN" "another prompt"

# Reset counter by deleting the file
rm -f "$STUB_COUNTER_FILE"
test_output_contains "stub counter resets after file delete" "LLM return 1" \
  env AGEN_BACKEND=stub "$AGEN" "test prompt"

# Piped input is consumed (doesn't block)
test_output_contains "stub handles piped input" "LLM return 2" \
  bash -c 'echo "piped data" | AGEN_BACKEND=stub AGEN_STUB_FILE='"$STUB_COUNTER_FILE"' '"$AGEN"' "process this"'

# Cleanup
rm -f "$STUB_COUNTER_FILE"
unset AGEN_STUB_FILE

# Summary
echo ""
echo "================================"
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi
