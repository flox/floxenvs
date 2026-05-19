#!/usr/bin/env bash
set -euo pipefail
# lms-launch — download, load, and launch agentic CLI tools against LM Studio

if [ $# -eq 0 ]; then
    echo "Usage: lms-launch <tool> --model <model> [options] [extra args...]"
    echo ""
    echo "Download, load, and launch an agentic CLI tool against a local LM Studio model."
    echo ""
    echo "Tools:"
    echo "  claude      Claude Code (Anthropic CLI agent)"
    echo "  codex       Codex (OpenAI CLI agent)"
    echo "  opencode    OpenCode (open-source AI agent)"
    echo ""
    echo "Options:"
    echo "  --model <model>           Model to use (REQUIRED)"
    echo "  --context-length <n>      Context window size (default: ${LMS_CONTEXT_LENGTH:-131072},"
    echo "                            override with LMS_CONTEXT_LENGTH)"
    echo "  --gpu <mode>              GPU offload mode (default: max if CUDA detected,"
    echo "                            omitted otherwise)"
    echo "  Extra arguments are passed through to the tool."
    echo ""
    echo "Examples:"
    echo "  lms-launch claude --model zai-org/glm-4.7-flash"
    echo "  lms-launch codex --model zai-org/glm-4.7-flash --context-length 65536"
    echo "  lms-launch opencode --model zai-org/glm-4.7-flash --gpu max"
    exit 0
fi

tool="$1"
shift

# Validate tool name early
case "$tool" in
    claude|codex|opencode) ;;
    *)
        echo "Unknown tool: $tool" >&2
        echo "" >&2
        echo "Supported tools: claude, codex, opencode" >&2
        echo "Run 'lms-launch' without arguments for usage." >&2
        exit 1
        ;;
esac

# Parse args: extract --model, --context-length, --gpu; rest passed to tool
model=""
ctx_length="${LMS_CONTEXT_LENGTH:-131072}"
gpu_flag=""
tool_args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --model)          model="$2"; shift 2 ;;
        --context-length) ctx_length="$2"; shift 2 ;;
        --gpu)            gpu_flag="$2"; shift 2 ;;
        *)                tool_args+=("$1"); shift ;;
    esac
done

if [ -z "$model" ]; then
    echo "Error: --model is required" >&2
    echo "  lms-launch $tool --model <model>" >&2
    exit 1
fi

HOST="${LMS_HOST:-127.0.0.1}"
PORT="${LMS_PORT:-1234}"
BASE="http://${HOST}:${PORT}"

# Health check: is the API server running?
if ! curl -sf "${BASE}/v1/models" >/dev/null 2>&1; then
    echo "Error: LM Studio API is not responding at ${BASE}" >&2
    echo "  Make sure the server is running: flox activate -s" >&2
    exit 1
fi

# Build the load command
load_cmd=(lms load "$model" --context-length "$ctx_length" -y)
if [ -n "$gpu_flag" ]; then
    load_cmd+=(--gpu "$gpu_flag")
elif [ "${_FLOX_ENV_CUDA_DETECTION:-0}" = "1" ]; then
    load_cmd+=(--gpu max)
fi

# Attempt to load model.
# Note: lms load may exit non-zero even on success (LM Studio CLI bug).
# We verify via lms status instead of trusting the exit code.
echo "Loading $model (context: $ctx_length)..."
"${load_cmd[@]}" 2>&1 || true

# Verify model actually loaded
if ! lms status 2>/dev/null | grep -qF "$model"; then
    echo "Model not loaded. Downloading $model..."
    if ! lms get "$model" -y 2>&1; then
        echo "Error: Failed to download $model" >&2
        exit 1
    fi
    echo "Loading $model (context: $ctx_length)..."
    "${load_cmd[@]}" 2>&1 || true
    if ! lms status 2>/dev/null | grep -qF "$model"; then
        echo "Error: Failed to load $model" >&2
        exit 1
    fi
fi
echo "Model loaded."

# Launch the tool
case "$tool" in
    claude)
        echo "Launching Claude Code against $model ..."
        exec env \
            ANTHROPIC_BASE_URL="${BASE}" \
            ANTHROPIC_AUTH_TOKEN="lmstudio" \
            ANTHROPIC_API_KEY="" \
            claude --model "$model" ${tool_args[@]+"${tool_args[@]}"}
        ;;
    codex)
        echo "Launching Codex against $model ..."
        exec env \
            OPENAI_BASE_URL="${BASE}/v1" \
            OPENAI_API_KEY="lm-studio" \
            codex --model "$model" ${tool_args[@]+"${tool_args[@]}"}
        ;;
    opencode)
        echo "Launching OpenCode against $model ..."
        # OpenCode does not read OPENAI_BASE_URL. It requires a custom provider
        # in opencode.json using @ai-sdk/openai-compatible with an explicit baseURL.
        # Models must also be declared in the provider config.
        _oc_config="${HOME}/.config/opencode/opencode.json"
        mkdir -p "${HOME}/.config/opencode"
        if [ -f "$_oc_config" ]; then
            _updated=$(jq --arg url "${BASE}/v1" --arg m "$model" '
                .provider.lmstudio = {
                    "npm": "@ai-sdk/openai-compatible",
                    "name": "LM Studio",
                    "options": { "baseURL": $url, "apiKey": "lm-studio" },
                    "models": { ($m): { "name": $m } }
                }
            ' "$_oc_config") && echo "$_updated" > "$_oc_config"
        else
            jq -n --arg url "${BASE}/v1" --arg m "$model" '{
                "$schema": "https://opencode.ai/config.json",
                "provider": {
                    "lmstudio": {
                        "npm": "@ai-sdk/openai-compatible",
                        "name": "LM Studio",
                        "options": { "baseURL": $url, "apiKey": "lm-studio" },
                        "models": { ($m): { "name": $m } }
                    }
                }
            }' > "$_oc_config"
        fi
        exec opencode --model "lmstudio/$model" ${tool_args[@]+"${tool_args[@]}"}
        ;;
esac
