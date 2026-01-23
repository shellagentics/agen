# Development Log

## Phase 0: Interface Contract

**Date:** 2026-01-23

### What was built

- `agent` script with `--help` and `--version` implemented
- All other options recognized but return "not yet implemented"
- Proper exit codes defined as named constants
- `README.md` with full usage documentation
- `test.sh` with test harness for verifying behavior

### Design decisions

1. **Named exit codes** - Using `EXIT_SUCCESS`, `EXIT_FAILURE`, etc. instead of magic numbers makes the code self-documenting and prevents errors.

2. **Help text structure** - Followed standard Unix man page conventions with SYNOPSIS, DESCRIPTION, OPTIONS, EXIT CODES, EXAMPLES, and ENVIRONMENT sections.

3. **Fail fast on unimplemented features** - Rather than silently ignoring unimplemented flags, we explicitly die with a message. This makes it clear what's available and what isn't.

4. **Test harness design** - Two types of tests:
   - `test_case` - verifies exit codes
   - `test_output_contains` - verifies output contains expected strings

### Tests passing

- `--help` exits 0 and contains "SYNOPSIS"
- `--version` exits 0 and contains version number
- No arguments exits 1
- Unimplemented prompt exits 1
- Unknown option exits 1

### Next phase

Phase 1 will implement the basic flow: stdin + prompt → LLM → stdout
