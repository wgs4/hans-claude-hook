# Hans Claude Hook

## ⚠️ SECURITY WARNING ⚠️

**🚨 DANGER: Claude hooks can be dangerous and may compromise your system! 🚨**

**⚠️ IMPORTANT: This repository contains executable scripts that will run code on your machine. ⚠️**

**🔒 SECURITY NOTICE:**

- **NEVER run Claude hooks without reviewing the code first**
- **These scripts have access to your system and can execute arbitrary commands**
- **Running untrusted code can lead to data loss, security breaches, or system compromise**
- **USE AT YOUR OWN RISK**

**📋 REQUIREMENT: You MUST inspect all hook scripts (including `.claude/hans/play.sh`) before use.**

---

## Overview

This repository contains a Claude hook script that provides text-to-speech notifications when Claude completes tasks. The script is designed to enhance the user experience by providing audio feedback when work is finished.

## What the Script Does

### Core Functionality

The `play.sh` script is a Claude hook that:

1. **Extracts User Prompts**: Reads the conversation transcript to identify the last user request
2. **Processes Content**: Uses OpenAI's GPT-4 to convert complex prompts into simple, readable summaries
3. **Text-to-Speech**: Plays audio notifications via ElevenLabs TTS when tasks are completed
4. **Fallback Support**: Includes multiple audio playback methods for different systems

### Detailed Process Flow

1. **Hook Data Processing**

   - Reads Claude hook data from stdin
   - Extracts transcript path and user prompt information
   - Falls back to direct prompt extraction if transcript parsing fails

2. **Prompt Simplification**

   - Sends the user's prompt to OpenAI GPT-4
   - Converts complex requests into simple 3-5 word summaries
   - Uses low temperature (0.3) for consistent, focused outputs

3. **Audio Generation & Playback**
   - Generates TTS audio via ElevenLabs API
   - Creates temporary MP3 files for playback
   - Attempts multiple audio players in order of preference:
     - `afplay` (macOS)
     - `ffplay` (FFmpeg)
     - `mpg123`
     - `mpv`
   - Falls back to system TTS (`say` command) if no players are available

### Configuration Requirements

The script requires several environment variables to function properly:

- **OpenAI**: `OPENAI_API_KEY` and optionally `OPENAI_MODEL` (defaults to `gpt-4o-mini`)
- **ElevenLabs**: `ELEVENLABS_API_KEY` and `ELEVENLABS_VOICE_ID`

These can be set in a `.labs` file in the script directory, current directory, or home directory.

### Dependencies

Required system commands:

- `curl` - For API requests
- `jq` - For JSON processing
- At least one audio player (see playback methods above)

## Installation & Setup

1. **Clone this repository**
2. **Review the script code thoroughly** (especially `.claude/hans/play.sh`)
3. **Create a `.labs` file at `.claude/hans/.labs`** with your API credentials:
   ```bash
   export OPENAI_API_KEY="your-openai-key-here"
   export ELEVENLABS_API_KEY="your-elevenlabs-key-here"
   export ELEVENLABS_VOICE_ID="your-voice-id-here"
   ```
4. **Ensure required dependencies are installed**:

   ```bash
   # macOS
   brew install jq ffmpeg

   # Ubuntu/Debian
   sudo apt install jq ffmpeg
   ```

## Usage

The script is designed to run automatically as a Claude hook. When Claude completes a task, it will:

1. Extract your original request
2. Convert it to a simple summary
3. Play an audio notification: "An agent finished their work on [summary]"

## Security Considerations

- **Script Review**: Always examine hook scripts before execution
- **API Keys**: Keep your API keys secure and never commit them to version control
- **Network Access**: The script makes external API calls to OpenAI and ElevenLabs
- **File System**: Creates temporary MP3 files during execution
- **Audio Playback**: May trigger system audio events

## Troubleshooting

### Common Issues

- **"No suitable audio player found"**: Install FFmpeg, mpg123, or mpv
- **"ElevenLabs API request failed"**: Check API key and voice ID
- **"OpenAI request failed"**: Verify API key and network connectivity

### Debug Mode

The script provides verbose output to help diagnose issues. Check the console output for detailed error messages.

## License

See [LICENSE](LICENSE) file for details.

## Disclaimer

**THE AUTHOR IS NOT LIABLE FOR ANY DAMAGE, DATA LOSS, OR SECURITY ISSUES RESULTING FROM THE USE OF THIS SCRIPT.**

This software is provided "as is" without warranty of any kind. Use at your own risk and always review code before execution.
