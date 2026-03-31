$ErrorActionPreference = "Stop"

Write-Host @"
COPILOT CLI POLICY ACTIVE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Prompts and tool use may be logged for auditing
• High-risk commands may be blocked automatically
• If something is blocked, follow the guidance shown
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"@
exit 0
