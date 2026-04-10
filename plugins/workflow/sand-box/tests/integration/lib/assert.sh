#!/bin/bash
# Sand-box v2 — Test assertions with structured report output

PASS=0
FAIL=0
REPORT_FILE="${SAND_BOX_REPORT_FILE:-/dev/null}"
CURRENT_TEST="${SAND_BOX_CURRENT_TEST:-unknown}"
ASSERT_N=0

# Write a report entry
_report() {
  local desc="$1" expected="$2" result="$3"
  ASSERT_N=$((ASSERT_N + 1))
  # Use tab-separated format (avoids JSON escaping issues)
  printf '%s\t%s\t%s\t%s\t%s\n' "$CURRENT_TEST" "$ASSERT_N" "$desc" "$expected" "$result" >> "$REPORT_FILE"
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    echo "  ✓ $msg"
    _report "$msg" "$needle" "PASS"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $msg"
    echo "    Expected to contain: $needle"
    echo "    Got: $(echo "$haystack" | head -3)"
    _report "$msg" "$needle" "FAIL"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if ! echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    echo "  ✓ $msg"
    _report "$msg" "NOT $needle" "PASS"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $msg"
    echo "    Expected NOT to contain: $needle"
    _report "$msg" "NOT $needle" "FAIL"
  fi
}

assert_exit_code() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [[ "$actual" -eq "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "  ✓ $msg"
    _report "$msg" "exit=$expected" "PASS"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $msg"
    echo "    Expected exit code: $expected, got: $actual"
    _report "$msg" "exit=$expected" "FAIL"
  fi
}

print_summary() {
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [[ "$FAIL" -gt 0 ]] && return 1
  return 0
}
