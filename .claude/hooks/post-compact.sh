#!/usr/bin/env bash
# post-compact.sh — fires after conversation compaction
# Reminds Claude to restore session state from the file-backed checkpoint.

# Run from the project root regardless of the caller's working directory.
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 0

ACTIVE="production/session-state/active.md"

echo "=== Context Restored After Compaction ==="

if [ -f "$ACTIVE" ]; then
  SIZE=$(wc -l < "$ACTIVE" 2>/dev/null || echo "?")
  echo "Session state file exists: $ACTIVE ($SIZE lines)"
  echo "IMPORTANT: Read this file now to restore your working context."
  echo "It contains: current task, decisions made, files in progress, open questions."
else
  echo "No session state file found at $ACTIVE"
  echo "If you were mid-task, check production/session-logs/ for the last session audit."
fi

echo "========================================="
