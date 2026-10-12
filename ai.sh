#!/usr/bin/env bash

# Exit immediately on unhandled error
set -e

# --- Color & Formatting Definitions ---
BOLD="\033[1m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# Model Configuration (Qwen2.5-Coder 7B Abliterated)
MODEL_NAME="hf.co/bartowski/Qwen2.5-Coder-7B-Instruct-abliterated-GGUF:Q4_K_M"

# Short, slash-free alias so every harness can reference the model cleanly
MODEL_ALIAS="qwen-coder-abliterated:latest"

# Local OpenAI/Anthropic compatible endpoint exposed by Ollama
OLLAMA_LOCAL_URL="http://127.0.0.1:11434"

# Clear terminal screen
clear

# --- ASCII Art Banner ---
cat << "EOF"
  _______                       __        __                   ______   ______         ______                      
/       \                     /  |      /  |                 /      \ /      |       /      \                     
$$$$$$$  |  ______    ______  $$ |   __ $$/   ______        /$$$$$$  |$$$$$$/       /$$$$$$  |  ______   _______  
$$ |  $$ | /      \  /      \ $$ |  /  |/  | /      \       $$ |__$$ |  $$ |        $$ | _$$/  /      \ /       \ 
$$ |  $$ | $$$$$$  |/$$$$$$  |$$ |_/$$/ $$ |/$$$$$$  |      $$    $$ |  $$ |        $$ |/    |/$$$$$$  |$$$$$$$  |
$$ |  $$ | /    $$ |$$ |  $$/ $$   $$<  $$ |$$    $$ |      $$$$$$$$ |  $$ |        $$ |$$$$ |$$    $$ |$$ |  $$ |
$$ |__$$ |/$$$$$$$ |$$ |      $$$$$$  \ $$ |$$$$$$$$/       $$ |  $$ | _$$ |_       $$ \__$$ |$$$$$$$$/ $$ |  $$ |
$$    $$/ $$    $$ |$$ |      $$ | $$  |$$ |$$       |      $$ |  $$ |/ $$   |      $$    $$/ $$       |$$ |  $$ |
$$$$$$$/   $$$$$$$/ $$/       $$/   $$/ $$/  $$$$$$$/       $$/   $$/ $$$$$$/        $$$$$$/   $$$$$$$/ $$/   $$/ 
                                                                                                                  
                                                                                                                  
                                                                                                                  
                                                                                                                      
EOF

echo -e "${CYAN}================================================================================${RESET}"
echo -e "${BOLD}           Abliterated AI Coding Server Setup Script                            ${RESET}"
echo -e "${CYAN}================================================================================${RESET}\n"

# --- User Confirmation Prompt ---
echo -ne "${BOLD}${YELLOW}Do you want to proceed with installing Ollama and setting up the abliterated AI model? (y/N): ${RESET}"
read -r CONFIRM

case "$CONFIRM" in
    [yY][eE][sS]|[yY])
        echo -e "\n${GREEN}[+] Starting setup process...${RESET}\n"
        ;;
    *)
        echo -e "\n${RED}[!] Setup cancelled by user. Exiting.${RESET}"
        exit 0
        ;;
esac

# --- Check & Install Ollama ---
if ! command -v ollama &> /dev/null; then
    echo -e "${YELLOW}[*] Ollama is not installed. Requesting sudo permissions to install...${RESET}"
    
    # Escalates to sudo only at the moment installation is required
    curl -fsSL https://ollama.com/install.sh | sudo sh
    
    if command -v ollama &> /dev/null; then
        echo -e "${GREEN}[✓] Ollama successfully installed!${RESET}\n"
    else
        echo -e "${RED}[✕] Ollama installation failed. Please check your internet or system dependencies.${RESET}"
        exit 1
    fi
else
    echo -e "${GREEN}[✓] Ollama is already installed on this system.${RESET}\n"
fi

# --- Check background service status ---
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "${YELLOW}[*] Ollama service is not running. Starting local server...${RESET}"
    ollama serve > /dev/null 2>&1 &
    sleep 3
fi

# --- Pull Model with Progress ---
echo -e "${CYAN}[*] Downloading and pulling model: ${BOLD}${MODEL_NAME}${RESET}"
echo -e "${YELLOW}Note: This may take a few minutes depending on your internet connection speed...${RESET}\n"

ollama run "$MODEL_NAME" ""

echo -e "\n${GREEN}[✓] Model successfully loaded and ready!${RESET}\n"

# --- Register a clean short alias (no slashes) for harness configs ---
if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$MODEL_ALIAS"; then
    echo -e "${GREEN}[✓] Alias already present: ${MODEL_ALIAS}${RESET}"
elif command -v ollama > /dev/null && ollama cp --help > /dev/null 2>&1; then
    ollama cp "$MODEL_NAME" "$MODEL_ALIAS" > /dev/null 2>&1 \
        && echo -e "${GREEN}[✓] Created model alias: ${MODEL_ALIAS}${RESET}" \
        || echo -e "${YELLOW}[!] Could not create alias ${MODEL_ALIAS}; harness configs will use the full model name.${RESET}"
else
    echo -e "${YELLOW}[!] 'ollama cp' unavailable; harness configs will use the full model name.${RESET}"
    MODEL_ALIAS="$MODEL_NAME"
fi

# --- Start Server & Display Endpoint Info ---
echo -ne "${BOLD}${YELLOW}Would you like to start the Ollama server service and view API connection details? (y/N): ${RESET}"
read -r START_SERVER

case "$START_SERVER" in
    [yY][eE][sS]|[yY])
        # Ensure systemd service starts if available, or confirm process status
        if command -v systemctl &> /dev/null && systemctl list-unit-files | grep -q "ollama.service"; then
            sudo systemctl enable --now ollama
        else
            if ! pgrep -x "ollama" > /dev/null; then
                nohup ollama serve > /tmp/ollama.log 2>&1 &
                sleep 2
            fi
        fi

        # Retrieve server IP address
        SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
        [ -z "$SERVER_IP" ] && SERVER_IP="127.0.0.1"

        echo -e "\n${GREEN}================================================================================${RESET}"
        echo -e "${BOLD}${GREEN}                        SETUP COMPLETE & RUNNING                                ${RESET}"
        echo -e "${GREEN}================================================================================${RESET}"
        echo -e "${BOLD}Local API URL:${RESET}         ${CYAN}http://127.0.0.1:11434${RESET}"
        echo -e "${BOLD}Network API URL:${RESET}       ${CYAN}http://${SERVER_IP}:11434${RESET}"
        echo -e "${BOLD}Installed Model:${RESET}       ${CYAN}${MODEL_NAME}${RESET}"
        echo -e "\n${BOLD}Example OpenAI-Compatible API Request:${RESET}"
        echo -e "${YELLOW}curl http://localhost:11434/v1/chat/completions \\"
        echo -e "  -H \"Content-Type: application/json\" \\"
        echo -e "  -d '{"
        echo -e "    \"model\": \"${MODEL_NAME}\","
        echo -e "    \"messages\": [{\"role\": \"user\", \"content\": \"Write a C function to reverse a string.\"}]"
        echo -e "  }'${RESET}\n"
        ;;
    *)
        echo -e "\n${CYAN}[I] Server start skipped. You can manually launch it later using 'ollama serve'.${RESET}"
        ;;
esac

# ============================================================================
#  HARNESS SETUP — Wire the local model into an AI coding harness
# ============================================================================

echo -e "\n${CYAN}--------------------------------------------------------------------------------${RESET}"
echo -e "${BOLD}Step 2 — Connect an AI coding harness${RESET}"
echo -e "${CYAN}--------------------------------------------------------------------------------${RESET}\n"

# --- Helper: is a command available? ---
have() { command -v "$1" > /dev/null 2>&1; }

# --- Helper: deep-merge a JSON patch into a config file ---
# Tries jq, then python3, then falls back to a backed-up fresh write.
merge_json() {
    local file="$1" patch="$2"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] || printf '%s' '{}' > "$file"

    if have jq && printf '%s' "$patch" | jq -s '.[0] * .[1]' "$file" - > "${file}.tmp" 2>/dev/null; then
        mv "${file}.tmp" "$file"
        return 0
    fi
    rm -f "${file}.tmp"

    if have python3 && PATCH="$patch" TARGET="$file" python3 - <<'PY' 2>/dev/null
import json, os

def deep_merge(base, patch):
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        else:
            base[key] = value
    return base

target = os.environ["TARGET"]
try:
    with open(target) as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError("not a json object")
except Exception:
    raise SystemExit(1)

deep_merge(data, json.loads(os.environ["PATCH"]))
with open(target, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY
    then
        return 0
    fi

    echo -e "  ${YELLOW}[!] Could not parse existing config. Backing it up to ${file}.bak${RESET}"
    cp "$file" "${file}.bak"
    printf '%s' "$patch" > "$file"
}

# --- Helper: make freshly installed CLIs visible to the current shell ---
refresh_shell() {
    export PATH="$HOME/.opencode/bin:$HOME/.claude/local/bin:$HOME/.local/bin:$PATH"
    if have npm; then
        NPM_BIN="$(npm prefix -g 2>/dev/null)/bin"
        [ -d "$NPM_BIN" ] && export PATH="$NPM_BIN:$PATH"
    fi
    hash -r 2>/dev/null || true

    # Re-read shell rc files so any PATH export the installers added takes effect,
    # without letting them abort the script or move us out of the current directory.
    local saved_pwd rc
    saved_pwd="$PWD"
    set +e
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        [ -f "$rc" ] && . "$rc" > /dev/null 2>&1
    done
    set -e
    cd "$saved_pwd" 2>/dev/null || true
}

# --- Helper: ask a yes/no question ---
confirm() {
    local reply
    echo -ne "  ${BOLD}${YELLOW}$1 (y/N): ${RESET}"
    read -r reply || reply=""
    case "$reply" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# --- Harness detection ---
HARNESS_NAMES=(opencode claude codex aider crush qwen gemini goose amp)
HARNESS_LABELS=("OpenCode" "Claude Code" "Codex CLI" "Aider" "Crush" "Qwen Code" "Gemini CLI" "Goose" "Amp")

echo -e "${BOLD}Scanning for installed AI coding harnesses...${RESET}\n"

FOUND_HARNESSES=()
for i in "${!HARNESS_NAMES[@]}"; do
    name="${HARNESS_NAMES[$i]}"
    label="${HARNESS_LABELS[$i]}"
    if path="$(command -v "$name" 2>/dev/null)"; then
        echo -e "  ${GREEN}[✓]${RESET} ${BOLD}${label}${RESET} ${YELLOW}($path)${RESET}"
        FOUND_HARNESSES+=("$name")
    else
        echo -e "  ${RED}[✕]${RESET} ${label} ${YELLOW}(not installed)${RESET}"
    fi
done

if [ ${#FOUND_HARNESSES[@]} -gt 0 ]; then
    echo -e "\n  ${CYAN}Detected: ${FOUND_HARNESSES[*]}${RESET}"
else
    echo -e "\n  ${CYAN}No AI coding harness found on this system yet.${RESET}"
fi

# --- Ask which harness to install / configure ---
echo -e "\n${BOLD}${YELLOW}Which harness would you like to install and point at the local model?${RESET}"
echo -e "  ${BOLD}1)${RESET} OpenCode      ${CYAN}(recommended — native Ollama provider)${RESET}"
echo -e "  ${BOLD}2)${RESET} Claude Code   ${CYAN}(Anthropic-compatible endpoint)${RESET}"
echo -e "  ${BOLD}3)${RESET} Both"
echo -e "  ${BOLD}4)${RESET} Skip harness setup\n"

echo -ne "${BOLD}${YELLOW}Choose an option [1]: ${RESET}"
read -r HARNESS_CHOICE || HARNESS_CHOICE="4"

case "$HARNESS_CHOICE" in
    1|"") SELECTED_HARNESSES=(opencode) ;;
    2)    SELECTED_HARNESSES=(claude) ;;
    3)    SELECTED_HARNESSES=(opencode claude) ;;
    *)    SELECTED_HARNESSES=() ;;
esac

if [ ${#SELECTED_HARNESSES[@]} -eq 0 ]; then
    echo -e "\n${CYAN}[I] Harness setup skipped.${RESET}"
    echo -e "${CYAN}    You can wire it up any time with: ${BOLD}ollama launch opencode${RESET} or ${BOLD}ollama launch claude${RESET}${RESET}\n"
    echo -e "${GREEN}[✓] Done!${RESET}"
    exit 0
fi

# --- Install the selected harnesses ---
echo -e "\n${BOLD}--- Installing harnesses ---${RESET}\n"

for harness in "${SELECTED_HARNESSES[@]}"; do
    case "$harness" in
        opencode)
            if have opencode; then
                echo -e "  ${GREEN}[✓]${RESET} OpenCode is already installed."
            elif confirm "OpenCode is not installed. Install it now?"; then
                echo -e "  ${CYAN}[*] Installing OpenCode...${RESET}"
                curl -fsSL https://opencode.ai/install | bash || \
                    echo -e "  ${YELLOW}[!] The OpenCode installer returned an error.${RESET}"
                refresh_shell
                have opencode && echo -e "  ${GREEN}[✓] OpenCode installed at $(command -v opencode)${RESET}" \
                              || echo -e "  ${RED}[✕] OpenCode installation failed.${RESET}"
            else
                echo -e "  ${CYAN}[I] OpenCode installation skipped.${RESET}"
            fi
            ;;
        claude)
            if have claude; then
                echo -e "  ${GREEN}[✓]${RESET} Claude Code is already installed."
            elif confirm "Claude Code is not installed. Install it now?"; then
                echo -e "  ${CYAN}[*] Installing Claude Code...${RESET}"
                curl -fsSL https://claude.ai/install.sh | bash || \
                    echo -e "  ${YELLOW}[!] The Claude Code installer returned an error.${RESET}"
                refresh_shell
                have claude && echo -e "  ${GREEN}[✓] Claude Code installed at $(command -v claude)${RESET}" \
                             || echo -e "  ${RED}[✕] Claude Code installation failed.${RESET}"
            else
                echo -e "  ${CYAN}[I] Claude Code installation skipped.${RESET}"
            fi
            ;;
    esac
done

# --- Refresh the terminal so new binaries resolve without a new shell ---
refresh_shell

# --- Point the harnesses at the local Ollama model ---
echo -e "\n${BOLD}--- Pointing harnesses at ${MODEL_ALIAS} ---${RESET}\n"

CONFIGURED_HARNESSES=()

for harness in "${SELECTED_HARNESSES[@]}"; do
    case "$harness" in
        opencode)
            if ! have opencode; then
                echo -e "  ${YELLOW}[!] OpenCode is not available; skipping its config.${RESET}"
                continue
            fi

            OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
            OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"
            # opencode also reads .jsonc; keep that file authoritative if it is the one in use
            if [ -f "$OPENCODE_CONFIG_DIR/opencode.jsonc" ] && [ ! -f "$OPENCODE_CONFIG_FILE" ]; then
                OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.jsonc"
            fi

            OPENCODE_PATCH=$(cat <<EOF
{
  "model": "ollama/$MODEL_ALIAS",
  "small_model": "ollama/$MODEL_ALIAS",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "$OLLAMA_LOCAL_URL/v1",
        "apiKey": "ollama"
      },
      "models": {
        "$MODEL_ALIAS": {
          "name": "Qwen2.5-Coder 7B Abliterated (local)",
          "limit": { "context": 32768, "output": 8192 }
        }
      }
    }
  }
}
EOF
)
            merge_json "$OPENCODE_CONFIG_FILE" "$OPENCODE_PATCH"
            echo -e "  ${GREEN}[✓]${RESET} OpenCode configured → ${CYAN}$OPENCODE_CONFIG_FILE${RESET}"
            CONFIGURED_HARNESSES+=("opencode")
            ;;

        claude)
            if ! have claude; then
                echo -e "  ${YELLOW}[!] Claude Code is not available; skipping its config.${RESET}"
                continue
            fi

            CLAUDE_CONFIG_DIR="$HOME/.claude"
            CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/settings.json"

            CLAUDE_PATCH=$(cat <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$OLLAMA_LOCAL_URL",
    "ANTHROPIC_AUTH_TOKEN": "ollama",
    "ANTHROPIC_API_KEY": "",
    "ANTHROPIC_MODEL": "$MODEL_ALIAS",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$MODEL_ALIAS",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$MODEL_ALIAS",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$MODEL_ALIAS"
  }
}
EOF
)
            merge_json "$CLAUDE_CONFIG_FILE" "$CLAUDE_PATCH"
            echo -e "  ${GREEN}[✓]${RESET} Claude Code configured → ${CYAN}$CLAUDE_CONFIG_FILE${RESET}"
            CONFIGURED_HARNESSES+=("claude")
            ;;
    esac
done

# --- Final summary ---
echo -e "\n${GREEN}================================================================================${RESET}"
echo -e "${BOLD}${GREEN}                     HARNESS SETUP COMPLETE                                      ${RESET}"
echo -e "${GREEN}================================================================================${RESET}"
echo -e "${BOLD}Model:${RESET}            ${CYAN}${MODEL_ALIAS}${RESET}"
echo -e "${BOLD}Local API:${RESET}        ${CYAN}${OLLAMA_LOCAL_URL}${RESET}"

if [ ${#CONFIGURED_HARNESSES[@]} -gt 0 ]; then
    echo -e "${BOLD}Configured:${RESET}       ${CYAN}${CONFIGURED_HARNESSES[*]}${RESET}"
fi

echo -e "\n${BOLD}Open a new terminal, then launch:${RESET}"
for harness in ${CONFIGURED_HARNESSES[@]+"${CONFIGURED_HARNESSES[@]}"}; do
    case "$harness" in
        opencode) echo -e "  ${CYAN}opencode${RESET}      # already defaults to the local model" ;;
        claude)   echo -e "  ${CYAN}claude${RESET}        # already defaults to the local model" ;;
    esac
done

echo -e "\n${YELLOW}Alternative (leaves the config files untouched):${RESET}"
echo -e "  ${CYAN}ollama launch opencode --model ${MODEL_ALIAS}${RESET}"
echo -e "  ${CYAN}ollama launch claude --model ${MODEL_ALIAS}${RESET}"

echo -e "\n${YELLOW}Other harnesses detected can be pointed at the same server with:${RESET}"
echo -e "  ${CYAN}ollama launch${RESET}   # interactive menu of supported integrations"

echo -e "\n${GREEN}[✓] Done!${RESET}"
