#!/bin/bash
set -euo pipefail

INPUT="$(cat)"

TOOL_NAME="$(echo "$INPUT" | jq -r '.toolName // empty')"
TOOL_ARGS_RAW="$(echo "$INPUT" | jq -r '.toolArgs // empty')"  # JSON string

LOG_DIR=".github/hooks/logs"
mkdir -p "$LOG_DIR"

# Example redaction logic.
# GitHub does not currently provide built-in secret redaction for hooks.
# This example shows one possible approach; many organizations prefer to
# forward events to a centralized logging system that handles redaction.
# Redact sensitive patterns before logging.
# Adjust these patterns to match your organization's needs.
REDACTED_TOOL_ARGS="$(echo "$TOOL_ARGS_RAW" | \
  sed -E 's/ghp_[A-Za-z0-9]{20,}/[REDACTED_TOKEN]/g' | \
  sed -E 's/gho_[A-Za-z0-9]{20,}/[REDACTED_TOKEN]/g' | \
  sed -E 's/ghu_[A-Za-z0-9]{20,}/[REDACTED_TOKEN]/g' | \
  sed -E 's/ghs_[A-Za-z0-9]{20,}/[REDACTED_TOKEN]/g' | \
  sed -E 's/Bearer [A-Za-z0-9_\-\.]+/Bearer [REDACTED]/g' | \
  sed -E 's/--password[= ][^ ]+/--password=[REDACTED]/g' | \
  sed -E 's/--token[= ][^ ]+/--token=[REDACTED]/g')"

# Log attempted tool use with redacted toolArgs.
jq -n \
  --arg tool "$TOOL_NAME" \
  --arg toolArgs "$REDACTED_TOOL_ARGS" \
  '{event:"preToolUse", toolName:$tool, toolArgs:$toolArgs}' \
  >> "$LOG_DIR/audit.jsonl"

# Only enforce command rules for bash.
if [ "$TOOL_NAME" != "bash" ]; then
  exit 0
fi

# Parse toolArgs JSON string.
# If toolArgs isn't valid JSON for some reason, allow (and rely on logs).
if ! echo "$TOOL_ARGS_RAW" | jq -e . >/dev/null 2>&1; then
  exit 0
fi

COMMAND="$(echo "$TOOL_ARGS_RAW" | jq -r '.command // empty')"

# ---------------------------------------------------------------------------
# Demo-only deny rule for safe testing.
# This blocks a harmless test command so you can validate the deny flow.
# Remove this rule after confirming your hooks work as expected.
# ---------------------------------------------------------------------------
if echo "$COMMAND" | grep -q "COPILOT_HOOKS_DENY_DEMO"; then
  deny "Blocked demo command (test rule). Remove this rule after validating hooks."
fi

deny() {
  local reason="$1"

  # Redact sensitive patterns from command before logging.
  local redacted_cmd="$(echo "$COMMAND" | \
    sed -E 's/ghp_[A-Za-z0-9]{20,}/[REDACTED_TOKEN]/g' | \
    sed -E 's/gho_[A-Za-z0-9]{20,}/[REDACTED_TOKEN]/g' | \
    sed -E 's/ghu_[A-Za-z0-9]{20,}/[REDACTED_TOKEN]/g' | \
    sed -E 's/ghs_[A-Za-z0-9]{20,}/[REDACTED_TOKEN]/g' | \
    sed -E 's/Bearer [A-Za-z0-9_\-\.]+/Bearer [REDACTED]/g' | \
    sed -E 's/--password[= ][^ ]+/--password=[REDACTED]/g' | \
    sed -E 's/--token[= ][^ ]+/--token=[REDACTED]/g')"

  # Log the denial decision with redacted command.
  jq -n \
    --arg cmd "$redacted_cmd" \
    --arg r "$reason" \
    '{event:"policyDeny", toolName:"bash", command:$cmd, reason:$r}' \
    >> "$LOG_DIR/audit.jsonl"

  # Return a denial response.
  jq -n \
    --arg r "$reason" \
    '{permissionDecision:"deny", permissionDecisionReason:$r}'

  exit 0
}

# Privilege escalation
if echo "$COMMAND" | grep -qE '\b(sudo|su|runas)\b'; then
  deny "Privilege escalation requires manual approval."
fi

# Destructive filesystem operations targeting root
if echo "$COMMAND" | grep -qE 'rm\s+-rf\s*/($|\s)|rm\s+.*-rf\s*/($|\s)'; then
  deny "Destructive operations targeting the filesystem root require manual approval."
fi

# System-level destructive operations
if echo "$COMMAND" | grep -qE '\b(mkfs|dd|format)\b'; then
  deny "System-level destructive operations are not allowed via automated execution."
fi

# Download-and-execute patterns
if echo "$COMMAND" | grep -qE 'curl.*\|\s*(bash|sh)|wget.*\|\s*(bash|sh)'; then
  deny "Download-and-execute patterns require manual approval."
fi

# Allow by default
exit 0
