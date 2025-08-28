#!/usr/bin/env bash

set -euo pipefail

# Log all output to debug file
exec 2>/tmp/permission_hook_errors.log

# Debug: Log that the hook was called
echo "PreToolUse hook triggered!" > /tmp/pretooluse_hook.log
date >> /tmp/pretooluse_hook.log

# "WARNING: This script is executed as a Claude hook and will run code on your machine."
# "Please inspect all hook scripts (.claude/hans/play.sh and others) before use."
# "Running untrusted code can be dangerous and may compromise your system."
# "USE AT YOUR OWN RISK. The author is not liable for any damage, data loss, or security issues resulting from the use of this script."

# Claude Code hook script that extracts original user prompt and outputs completion notification
# Extracts the last user prompt from the conversation and saves it to tmp.txt

# Attempt to source .labs for credentials (script dir, current dir, or $HOME)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABS_CANDIDATES=(
  "$SCRIPT_DIR/.labs"
  ".labs"
  "$HOME/.labs"
)

for labs_file in "${LABS_CANDIDATES[@]}"; do
  if [[ -f "$labs_file" ]]; then
    set +u
    set -a
    # shellcheck disable=SC1090
    source "$labs_file"
    set +a
    set +u
    break
  fi
done

OPENAI_KEY="${OPENAI_API_KEY:-}"
OPENAI_MODEL="${OPENAI_MODEL:-gpt-4o-mini}"
ELEVENLABS_API_KEY="${ELEVENLABS_API_KEY:-}"
ELEVENLABS_VOICE_ID="${ELEVENLABS_VOICE_ID:-}"

# Read hook data from stdin
HOOK_DATA=""

if [[ ! -t 0 ]]; then
  # Read all stdin
  HOOK_DATA=$(cat)
fi

TRANSCRIPT_PATH=$(echo "$HOOK_DATA" | jq -r '.transcript_path')


# For PreToolUse hook, extract the tool name and parameters
TOOL_NAME=$(echo "$HOOK_DATA" | jq -r '.tool_name // empty')
TOOL_PARAMS=$(echo "$HOOK_DATA" | jq -r '.tool_input // empty')

# Debug: log the full hook data
echo "$HOOK_DATA" > /tmp/hook_data_debug.json
echo "Tool: $TOOL_NAME" >> /tmp/pretooluse_hook.log

# Check if this tool is in the allowed list
SETTINGS_FILE="/Users/david/code/.claude/settings.local.json"
IS_ALLOWED="no"

if [[ -f "$SETTINGS_FILE" ]] && [[ -n "$TOOL_NAME" ]]; then
  # Check if this tool/command is in the allowed list
  if [[ "$TOOL_NAME" == "Bash" ]]; then
    # For Bash commands, extract the actual command
    COMMAND=$(echo "$TOOL_PARAMS" | jq -r '.command // empty')
    if [[ -n "$COMMAND" ]]; then
      # Check if this command matches any allowed Bash pattern
      IS_ALLOWED=$(cat "$SETTINGS_FILE" | jq -r '.permissions.allow[]' | while read -r pattern; do
        if [[ "$pattern" == "Bash("* ]]; then
          # Extract the command pattern from "Bash(command:*)"
          ALLOWED_PATTERN=$(echo "$pattern" | sed 's/Bash(//' | sed 's/)$//')
          
          # Check if pattern ends with :* (wildcard)
          if [[ "$ALLOWED_PATTERN" == *":*" ]]; then
            # Remove the :* to get the base command
            ALLOWED_CMD=$(echo "$ALLOWED_PATTERN" | sed 's/:.*$//')
            
            # Check if our command starts with this allowed command
            if [[ "$COMMAND" == "$ALLOWED_CMD"* ]]; then
              echo "yes"
              break
            fi
          else
            # Exact match required (no wildcard)
            if [[ "$COMMAND" == "$ALLOWED_PATTERN" ]]; then
              echo "yes"
              break
            fi
          fi
        fi
      done)
      
      PROMPT="run command: $COMMAND"
    fi
  else
    # For non-Bash tools, check if the tool itself is in the allowed list
    IS_ALLOWED=$(cat "$SETTINGS_FILE" | jq -r '.permissions.allow[]' | while read -r pattern; do
      # Check for exact tool match (like "Read", "Write", "Edit", etc.)
      if [[ "$pattern" == "$TOOL_NAME" ]]; then
        echo "yes"
        break
      fi
    done)
    
    PROMPT="use $TOOL_NAME tool"
  fi
fi

# If tool/command is allowed, exit early without speaking
if [[ "$IS_ALLOWED" == "yes" ]]; then
  echo "Tool/command is allowed, skipping notification" >> /tmp/pretooluse_hook.log
  exit 0
fi

# Create a description of what tool is being used
if [[ -z "$PROMPT" ]]; then
  if [[ -n "$TOOL_NAME" ]]; then
    PROMPT="use $TOOL_NAME tool"
  else
    PROMPT="perform an action"
  fi
fi

# Fallback to general permission request if we can't determine the tool
if [[ -z "$PROMPT" ]]; then
  PROMPT="perform an action"
fi

# Check if required commands are available
for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

# Convert PROMPT to a simple sentence using GPT-4
SIMPLE_MESSAGE="$PROMPT"
if [[ -n "$OPENAI_KEY" && -n "$PROMPT" ]]; then
  echo "Converting prompt to simple sentence via OpenAI..."
  echo "DEBUG: Prompt being sent: '$PROMPT'"
  echo "$PROMPT" > /tmp/claude_hook_debug.txt
  OPENAI_BODY=$(jq -n \
    --arg model "$OPENAI_MODEL" \
    --arg prompt "$PROMPT" \
    '{
      model: $model,
      messages: [
        {
          role: "system",
          content: "Summarize this tool action or command in 2-4 words. Be concise and specific. Examples: run tests, install package, read file, edit code."
        },
        {
          role: "user",
          content: ("" + $prompt)
        }
      ],
      temperature: 0.3
    }')
    
  OPENAI_RESP=$(curl -sS -f -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer ${OPENAI_KEY}" \
    -H "Content-Type: application/json" \
    --data "$OPENAI_BODY") || true

  if [[ -n "${OPENAI_RESP:-}" ]]; then
    CANDIDATE=$(printf '%s' "$OPENAI_RESP" | jq -r '.choices[0].message.content // empty')
    if [[ -n "$CANDIDATE" ]]; then
      SIMPLE_MESSAGE="$CANDIDATE"
      echo "Converted to: $SIMPLE_MESSAGE"
    else
      echo "Warning: OpenAI returned an empty response; using original prompt." >&2
    fi
  else
    echo "Warning: OpenAI request failed; using original prompt." >&2
  fi
fi


# Play the message via ElevenLabs TTS if credentials are available
if [[ -n "$ELEVENLABS_API_KEY" && -n "$ELEVENLABS_VOICE_ID" ]]; then
  echo "Playing message via ElevenLabs TTS..."
  
  TMP_MP3="$(mktemp -t play.XXXXXX).mp3"
  
  # Prepare JSON using jq to safely handle arbitrary message text
  JSON_BODY=$(jq -n --arg text "Do I have permission to $SIMPLE_MESSAGE?" '{
    text: $text,
    model_id: "eleven_multilingual_v2",
    voice_settings: {
      stability: 0.35,
      similarity_boost: 0.85,
      style: 0.60,
      use_speaker_boost: true
    }
  }')
  
  if curl -sS -f -X POST "https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}?output_format=mp3_44100_128" \
    -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY" \
    -o "$TMP_MP3"; then
    
    # Function to play audio with fallbacks
    play_audio() {
      local file="$1"
      if command -v afplay >/dev/null 2>&1; then
        afplay "$file"
      elif command -v ffplay >/dev/null 2>&1; then
        ffplay -autoexit -nodisp -loglevel error "$file" </dev/null >/dev/null 2>&1
      elif command -v mpg123 >/dev/null 2>&1; then
        mpg123 -q "$file"
      elif command -v mpv >/dev/null 2>&1; then
        mpv --really-quiet --no-video "$file" </dev/null >/dev/null 2>&1
      else
        return 1
      fi
    }
    
    echo "Playing audio..."
    if ! play_audio "$TMP_MP3"; then
      echo "Warning: No suitable audio player found. Falling back to system TTS if available." >&2
      if command -v say >/dev/null 2>&1; then
        say "$SIMPLE_MESSAGE"
      else
        echo "Error: Could not play audio. Please install 'ffplay' (ffmpeg), 'mpg123', or 'mpv'." >&2
      fi
    fi
    
    rm -f "$TMP_MP3"
  else
    echo "Error: ElevenLabs API request failed. Please check your API key, voice ID, and network connection." >&2
    rm -f "$TMP_MP3"
  fi
else
  echo "ElevenLabs credentials not found. Message saved to tmp.txt but not played."
  echo "To enable TTS, set ELEVENLABS_API_KEY and ELEVENLABS_VOICE_ID in your .labs file."
fi

