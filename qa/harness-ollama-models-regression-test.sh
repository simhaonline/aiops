#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/harness-manager"
LEGACY="$ROOT/legacy/harness-manager.sh"

run_parser_suite(){
  local target="$1"
  (
    # shellcheck disable=SC1090
    source "$target"
    trap - ERR

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    cat >"$tmp/openai-null.json" <<'JSON'
{"object":"list","data":null}
JSON
    [[ -z "$(hm_extract_ollama_model_ids openai "$tmp/openai-null.json")" ]]

    cat >"$tmp/openai-list.json" <<'JSON'
{"object":"list","data":[{"id":"kimi-k2.5:cloud"},null,{},{"id":17},{"id":"glm-5:cloud"},{"id":"kimi-k2.5:cloud"}]}
JSON
    mapfile -t ids < <(hm_extract_ollama_model_ids openai "$tmp/openai-list.json")
    [[ "${#ids[@]}" -eq 2 ]]
    [[ "${ids[0]}" == "kimi-k2.5:cloud" ]]
    [[ "${ids[1]}" == "glm-5:cloud" ]]

    cat >"$tmp/native-list.json" <<'JSON'
{"models":[{"name":"kimi-k2.5:cloud","model":"kimi-k2.5:cloud"},{"name":"glm-5:cloud"},{"model":"qwen3-coder:cloud"},null,{}]}
JSON
    mapfile -t ids < <(hm_extract_ollama_model_ids native "$tmp/native-list.json")
    [[ "${#ids[@]}" -eq 3 ]]
    [[ "${ids[0]}" == "kimi-k2.5:cloud" ]]
    [[ "${ids[1]}" == "glm-5:cloud" ]]
    [[ "${ids[2]}" == "qwen3-coder:cloud" ]]

    printf '{"models":null}\n' >"$tmp/native-null.json"
    [[ -z "$(hm_extract_ollama_model_ids native "$tmp/native-null.json")" ]]

    printf '{"data":' >"$tmp/malformed.json"
    if hm_extract_ollama_model_ids openai "$tmp/malformed.json" >/dev/null 2>&1; then
      echo "malformed JSON unexpectedly passed" >&2
      exit 1
    fi

    # Exercise the real discovery order with mocked curl:
    # native endpoint first returns no list; OpenAI endpoint returns data:null.
    # The function must complete successfully and print nothing.
    curl(){
      local out="" url="" arg
      while (($#)); do
        arg="$1"
        case "$arg" in
          -o) out="${2:-}"; shift 2 ;;
          http://*|https://*) url="$arg"; shift ;;
          *) shift ;;
        esac
      done
      [[ -n "$out" && -n "$url" ]] || return 2
      case "$url" in
        */api/tags) printf '{"models":null}\n' >"$out" ;;
        */v1/models) printf '{"object":"list","data":null}\n' >"$out" ;;
        *) return 3 ;;
      esac
    }
    [[ -z "$(hm_ollama_model_ids)" ]]

    # Native inventory wins when models are present.
    curl(){
      local out="" url="" arg
      while (($#)); do
        arg="$1"
        case "$arg" in
          -o) out="${2:-}"; shift 2 ;;
          http://*|https://*) url="$arg"; shift ;;
          *) shift ;;
        esac
      done
      [[ -n "$out" && -n "$url" ]] || return 2
      case "$url" in
        */api/tags)
          printf '{"models":[{"name":"kimi-k2.5:cloud"},{"name":"glm-5:cloud"}]}\n' >"$out"
          ;;
        */v1/models)
          echo "OpenAI fallback should not be called when native inventory is populated" >&2
          return 9
          ;;
        *) return 3 ;;
      esac
    }
    mapfile -t ids < <(hm_ollama_model_ids)
    [[ "${#ids[@]}" -eq 2 ]]
    [[ "${ids[0]}" == "kimi-k2.5:cloud" ]]
    [[ "${ids[1]}" == "glm-5:cloud" ]]
  )
}

run_parser_suite "$SCRIPT"
run_parser_suite "$LEGACY"

echo 'HARNESS OLLAMA MODEL DISCOVERY REGRESSION: PASS'
