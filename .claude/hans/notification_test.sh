#!/usr/bin/env bash

set -euo pipefail

# Log that the notification hook was called
echo "Notification hook triggered at $(date)" >> /tmp/notification_hook.log

# Read hook data from stdin
HOOK_DATA=""
if [[ ! -t 0 ]]; then
  HOOK_DATA=$(cat)
fi

# Log the full hook data
echo "$HOOK_DATA" >> /tmp/notification_hook_data.json

# Extract notification type and message
NOTIFICATION_TYPE=$(echo "$HOOK_DATA" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$HOOK_DATA" | jq -r '.message // "no message"')

echo "Type: $NOTIFICATION_TYPE" >> /tmp/notification_hook.log
echo "Message: $MESSAGE" >> /tmp/notification_hook.log
echo "---" >> /tmp/notification_hook.log