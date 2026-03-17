#!/bin/bash
# Notification hook: Send macOS notification when Claude needs input.

/usr/bin/osascript -e 'display notification "Claude Code needs your attention" with title "My Project" sound name "Glass"'
exit 0
