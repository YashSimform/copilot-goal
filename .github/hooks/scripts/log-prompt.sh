#!/bin/bash
set -euo pipefail

INPUT="$(cat)"

TIMESTAMP_MS="$(echo "$INPUT" | jq -r '.timestamp // empty')"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"
PROMPT="$(echo "$INPUT" | jq -r '.prompt // empty')"

LOG_DIR=".github/hooks/logs"
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

jq -n \
  --arg ts "$TIMESTAMP_MS" \
  --arg cwd "$CWD" \
  --arg prompt "$PROMPT" \
  '{event:"userPromptSubmitted", timestampMs:$ts, cwd:$cwd, prompt:$prompt}' \
  >> "$LOG_DIR/audit.jsonl"

exit 0
