#!/bin/bash
# ─── Status Line for Claude Code ───────────────────────────────────────────────
# Customize this file to control what appears in your Claude Code status line.
# The commented field reference below lists every available JSON input field so
# you can pick and compose your own layout.

# ─── ALL AVAILABLE JSON INPUT FIELDS ─────────────────────────────────────────
# Read via: echo "$input" | jq -r '.path.to.field // "fallback"'
#
# 🆔  .session_id                  — Unique session identifier
# 🏷️  .session_name                — Human-readable session name (set via /rename)
# 📝  .transcript_path             — Path to the conversation transcript file
# 📂  .cwd                          — Current working directory (top-level)
# 🤖  .model.id                     — Model ID (e.g. "claude-sonnet-4-6")
# 🤖  .model.display_name          — Model display name (e.g. "Claude Sonnet 4.6")
# 📁  .workspace.current_dir       — Current working directory path
# 📁  .workspace.project_dir       — Project root directory path
# 📁  .workspace.added_dirs[]      — Directories added via /add-dir
# 🌿  .workspace.git_worktree      — Git worktree name (when cwd is in a linked worktree)
# 🔢  .version                      — Claude Code app version (e.g. "1.0.71")
# 🎨  .output_style.name           — Output style name (e.g. "default", "Explanatory")
# 🧠  .context_window.total_input_tokens       — Cumulative input tokens in session
# 🧠  .context_window.total_output_tokens      — Cumulative output tokens in session
# 🧠  .context_window.context_window_size      — Context window size for current model
# 🧠  .context_window.current_usage            — Token usage from last API call (or null)
# 🧠  .context_window.current_usage.input_tokens             — Input tokens (last call)
# 🧠  .context_window.current_usage.output_tokens            — Output tokens (last call)
# 🧠  .context_window.current_usage.cache_creation_input_tokens — Tokens written to cache
# 🧠  .context_window.current_usage.cache_read_input_tokens    — Tokens read from cache
# 🧠  .context_window.used_percentage            — % of context window used (0–100, or null)
# 🧠  .context_window.remaining_percentage       — % of context window remaining (0–100, or null)
# ⚡  .effort.level                — Reasoning effort: "low" | "medium" | "high" | "xhigh" | "max"
# 💭  .thinking.enabled            — Whether extended thinking is enabled
# ⏳  .rate_limits.five_hour.used_percentage     — 5-hour rate limit % used (subscribers, or null)
# ⏳  .rate_limits.five_hour.resets_at           — Unix epoch when 5-hour window resets
# ⏳  .rate_limits.seven_day.used_percentage     — 7-day rate limit % used (or null)
# ⏳  .rate_limits.seven_day.resets_at           — Unix epoch when 7-day window resets
# ⌨️  .vim.mode                     — Vim editor mode: "INSERT" | "NORMAL" | "VISUAL" | "VISUAL LINE"
# 🎯  .agent.name                  — Agent name (e.g. "code-architect")
# 🎯  .agent.type                  — Agent type identifier
# 🌲  .worktree.name               — Worktree name/slug (e.g. "my-feature")
# 🌲  .worktree.path               — Full path to the worktree directory
# 🌲  .worktree.branch             — Git branch name for the worktree
# 🌲  .worktree.original_cwd       — The directory Claude was in before entering the worktree
# 🌲  .worktree.original_branch    — Branch that was checked out before entering the worktree

# ─── MODEL PRICING (milli-CNY per 1M tokens, i.e. price_in_¥ × 1000) ─────────
# Edit these integers directly. No external tools needed for cost math.
# Examples: ¥3.00 = 3000, ¥0.025 = 25, ¥6.00 = 6000
lookup_prices() {
  local id="$1"
  case "$id" in
    *"deepseek-v4-pro"*)   echo "3000 25 6000" ;;      # ¥3.00 / ¥0.025 / ¥6.00
    *"deepseek-v4-flash"*) echo "1000 20 2000" ;;      # ¥1.00 / ¥0.020 / ¥2.00
    *"claude-opus-4.6"*)   echo "12000 100 24000" ;;   # ¥12.00 / ¥0.10 / ¥24.00
    *)                     echo "15000 1500 75000" ;;  # ¥15.00 / ¥1.50 / ¥75.00 (default)
  esac
}

# ─── PARSE INPUT JSON ─────────────────────────────────────────────────────────
input=$(cat)

MODEL_ID=$(echo "$input" | jq -r '.model.id // ""')
MODEL_NAME=$(echo "$input" | jq -r '.model.display_name // "?"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "."')

# Resolve price by model (returns three integers: input cached output in milli-CNY/1M)
read INPUT_PRICE CACHED_PRICE OUTPUT_PRICE <<< "$(lookup_prices "$MODEL_ID")"

# Context usage — used_percentage is pre-calculated by Claude Code (null before first API call)
USED=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Per-call token usage from the most recent API call
IN_CURR=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
CACHE_CURR=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
OUT_CURR=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')

# ─── SESSION ACCUMULATOR ────────────────────────────────────────────────────
# Accumulate IN_CURR/CACHE_CURR/OUT_CURR across all turns using a state file,
# keyed by session_id.  Use total_input_tokens as a monotonic guard to detect
# new API calls and avoid double-counting.
IN_TOK=$IN_CURR; CACHE_TOTAL=$CACHE_CURR; OUT_TOK=$OUT_CURR
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')
if [ -n "$SESSION_ID" ]; then
  STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/claude-statusline"
  STATE_FILE="${STATE_DIR}/${SESSION_ID}"
  mkdir -p "$STATE_DIR" 2>/dev/null
  # State format: total_input_guard acc_in acc_cache acc_out
  TOTAL_GUARD=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
  last_guard=0; acc_in=0; acc_cache=0; acc_out=0
  [ -f "$STATE_FILE" ] && read -r last_guard acc_in acc_cache acc_out < "$STATE_FILE" 2>/dev/null || :
  if [ "$TOTAL_GUARD" -gt "$last_guard" ]; then
    acc_in=$((acc_in + IN_CURR))
    acc_cache=$((acc_cache + CACHE_CURR))
    acc_out=$((acc_out + OUT_CURR))
  fi
  printf "%s %s %s %s" "$TOTAL_GUARD" "$acc_in" "$acc_cache" "$acc_out" > "$STATE_FILE.tmp" 2>/dev/null \
    && mv "$STATE_FILE.tmp" "$STATE_FILE" 2>/dev/null
  IN_TOK=$acc_in; CACHE_TOTAL=$acc_cache; OUT_TOK=$acc_out
fi

# ─── PROGRESS BAR ─────────────────────────────────────────────────────────────
# Draws an ASCII progress bar of WIDTH characters, e.g. "[████░░░░░░] 42%"
draw_bar() {
  local pct="${1:-0}"   # percentage as integer (0–100)
  local width="${2:-10}"
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  local i
  for (( i = 0; i < filled; i++ )); do bar+="█"; done
  for (( i = 0; i < empty;  i++ )); do bar+="░"; done
  printf '[%s] %d%%' "$bar" "$pct"
}

# ─── COST CALCULATION (pure bash integer arithmetic, no external deps) ────────
cost_str=""
if [ "$IN_TOK" -gt 0 ] || [ "$CACHE_TOTAL" -gt 0 ] || [ "$OUT_TOK" -gt 0 ]; then
  # All prices are in milli-CNY per 1M tokens
  # cost_milli = (tokens * price_per_1M_tokens_in_milliCNY) / 1,000,000
  cost_milli=$(( (IN_TOK * INPUT_PRICE + CACHE_TOTAL * CACHED_PRICE + OUT_TOK * OUTPUT_PRICE) / 1000000 ))
  yuan=$(( cost_milli / 1000 ))
  frac=$(( cost_milli % 1000 ))
  # frac may be negative if cost_milli is negative; take absolute value
  [ "$frac" -lt 0 ] && frac=$(( -frac ))
  cost_str=$(printf "¥%d.%03d" "$yuan" "$frac")
fi

# ─── TOKEN FORMATTER ──────────────────────────────────────────────────────────
# Converts token count to K format (e.g. 15200 → 15.2K, 800 → 0.8K)
fmt_k() {
  local t="$1"
  if [ "$t" -ge 1000 ]; then
    local k=$(( t / 100 ))
    printf "%d.%dK" $(( k / 10 )) $(( k % 10 ))
  else
    printf "%d" "$t"
  fi
}

# ─── ASSEMBLE STATUS LINE ────────────────────────────────────────────────────
parts=()

parts+=("[$DIR]")
parts+=("[${MODEL_NAME}]")

if [ -n "$USED" ]; then
  USED_INT=$(printf "%.0f" "$USED")
  BAR=$(draw_bar "$USED_INT" 10)
  parts+=("${BAR}")
fi

if [ "$IN_TOK" -gt 0 ] || [ "$CACHE_TOTAL" -gt 0 ] || [ "$OUT_TOK" -gt 0 ]; then
  in_k=$(fmt_k "$IN_TOK")
  cache_k=$(fmt_k "$CACHE_TOTAL")
  out_k=$(fmt_k "$OUT_TOK")
  parts+=("[⬆${in_k}/${cache_k}/⬇${out_k} ${cost_str}]")
fi

(
  IFS=' | '
  printf "%s" "${parts[*]}"
)
