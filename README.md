# Claude Code Audio Notification Hooks

Intelligent audio notifications for Claude Code that announce permission requests and task completions using OpenAI and ElevenLabs TTS.

## ⚠️ Security Notice

This repository contains executable scripts that will run as Claude hooks. Please review all scripts before use. Running untrusted code can be dangerous and may compromise your system. USE AT YOUR OWN RISK.

## Features

- 🔊 **Permission Alerts**: Audibly announces when Claude needs permission to run a command
- ✅ **Completion Notifications**: Announces when Claude completes a task  
- 🧠 **Smart Filtering**: Only speaks for commands that actually need permission
- 🎯 **Dynamic Configuration**: Reads your Claude settings to determine what's allowed
- 🌍 **Fully Portable**: Works on any machine with proper setup

## How It Works

1. **PreToolUse Hook**: Fires before Claude uses any tool
   - Checks if the tool/command is in your allowed list
   - If NOT allowed, speaks "Do I have permission to [action]?"
   - Silent for all allowed commands

2. **Stop Hook**: Fires when Claude finishes responding
   - Summarizes what was completed
   - Speaks "[task] completed"

## Prerequisites

- Claude Code installed
- OpenAI API key (for text summarization)
- ElevenLabs API key (for text-to-speech)
- Audio player (afplay on macOS, ffplay, mpg123, or mpv on Linux)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/wgs4/hans-claude-hook.git ~/hans-claude-hook
```

### 2. Set Up API Keys

Create a `.claude/hans/.labs` file with your API keys:

```bash
cat > ~/hans-claude-hook/.claude/hans/.labs << 'EOF'
# API Keys for audio notifications
export OPENAI_API_KEY="your-openai-api-key-here"
export ELEVENLABS_API_KEY="your-elevenlabs-api-key-here"
export ELEVENLABS_VOICE_ID="your-elevenlabs-voice-id-here"
EOF
```

### 3. Configure Claude Settings

You need to add the hooks to your Claude settings. The location depends on your setup:

#### Option A: Project-Specific Settings (Recommended)
Add to `.claude/settings.local.json` in your project directory:

```bash
# Navigate to your project
cd /path/to/your/project

# Create .claude directory if it doesn't exist
mkdir -p .claude

# Copy and customize the example settings
cp ~/hans-claude-hook/example-settings.json .claude/settings.local.json
```

#### Option B: Global Settings
Add to `~/.claude/settings.local.json` for all projects:

```bash
# Copy and customize the example settings
cp ~/hans-claude-hook/example-settings.json ~/.claude/settings.local.json
```

#### Option C: Use the Setup Script (Easiest)
Run the provided setup script to automatically configure your hooks:

```bash
cd ~/hans-claude-hook
./setup.sh
```

### 4. Customize Allowed Commands

Edit your `settings.local.json` to add commands that should run WITHOUT audio notifications:

```json
{
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(npm:*)",
      "Read",
      "Write",
      "Edit"
    ]
  }
}
```

### 5. Make Scripts Executable

```bash
chmod +x ~/hans-claude-hook/.claude/hans/*.sh
```

## Configuration Details

### Settings File Structure

The hooks read from your Claude settings file to determine what's allowed:

- **Default Location**: `/Users/david/code/.claude/settings.local.json`
  - Update the `SETTINGS_FILE` path in `play_permission.sh` line 65 for your setup
- **Permissions**: List of allowed commands/tools that won't trigger audio
- **Hooks**: Configuration for when hooks should fire

### Understanding Settings Priority

Claude checks settings in this order:
1. Project-specific: `.claude/settings.local.json` in your current project
2. Global: `~/.claude/settings.local.json`

The project settings take precedence and are where both hooks and permissions should be configured.

### Customizing the Audio Messages

Edit the scripts to change what's spoken:

- **Permission requests** (`play_permission.sh`): Line 131
  ```bash
  JSON_BODY=$(jq -n --arg text "Do I have permission to $SIMPLE_MESSAGE?" ...
  ```

- **Completion messages** (`play.sh`): Line 122
  ```bash
  JSON_BODY=$(jq -n --arg text "$SIMPLE_MESSAGE completed" ...
  ```

## Troubleshooting

### No Audio Playing

1. Check API keys are set correctly in `.labs` file
2. Verify audio player is installed (`afplay`, `ffplay`, `mpg123`, or `mpv`)
3. Check `/tmp/pretooluse_hook.log` for errors
4. Check `/tmp/permission_hook_errors.log` for script errors

### Wrong Commands Triggering Audio

1. Add the command to your `allow` list in settings
2. Use wildcards: `"Bash(command:*)"` allows all variations
3. Remember non-Bash tools need just the tool name: `"Read"`, `"Write"`

### Hooks Not Firing

1. Restart Claude Code after changing settings
2. Verify hooks are in the correct settings file (project takes precedence)
3. Check that scripts are executable
4. Run `claude code` with `--debug hooks` to see hook execution

### Testing Your Setup

Test if audio works:
```bash
# Test completion notification
echo "test" | ~/hans-claude-hook/.claude/hans/play.sh

# Test permission notification
echo '{"tool_name":"Bash","tool_input":{"command":"curl test"}}' | ~/hans-claude-hook/.claude/hans/play_permission.sh
```

## How the Permission Checking Works

The `play_permission.sh` script:
1. Reads your Claude settings file dynamically
2. Extracts the list of allowed commands/tools
3. For Bash commands: checks against patterns like `"Bash(git status:*)"`
4. For other tools: checks against tool names like `"Read"`, `"Write"`
5. Only speaks if the command/tool is NOT in the allow list

This makes the system completely dynamic - it adapts to whatever permissions you have set!

## Files in This Repository

- `.claude/hans/play.sh` - Completion notification script
- `.claude/hans/play_permission.sh` - Permission request notification script
- `.claude/hans/notification_test.sh` - Debug script for testing notifications
- `example-settings.json` - Example Claude settings configuration
- `setup.sh` - Automated setup script

## Contributing

Feel free to submit issues and pull requests to improve the notification system.

## License

MIT

## Credits

Created with Claude Code 🤖