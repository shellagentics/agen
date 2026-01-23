#!/usr/bin/env bash
set -euo pipefail

# Test harness for agent CLI
# Run: ./test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT="$SCRIPT_DIR/agent"

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
  local exit_code=$?
  set -e

  if echo "$output" | grep -q "$pattern"; then
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name (output does not contain '$pattern')"
  fi
}

echo "Running agent CLI tests..."
echo ""

# Phase 0 tests
echo "=== Phase 0: Interface Contract ==="

test_case "--help exits 0" 0 "$AGENT" --help
test_output_contains "--help contains SYNOPSIS" "SYNOPSIS" "$AGENT" --help
test_output_contains "--help contains OPTIONS" "OPTIONS" "$AGENT" --help

test_case "--version exits 0" 0 "$AGENT" --version
test_output_contains "--version contains version number" "0.1.0" "$AGENT" --version

test_case "no arguments exits 1" 1 "$AGENT"
test_case "prompt without implementation exits 1" 1 "$AGENT" "anything"
test_case "unknown option exits 1" 1 "$AGENT" --unknown-flag

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
