#!/bin/bash
# avila-tek-skill-pack session-start hook
# 1. Loads the using-agent-skills meta-skill into every session
# 2. Detects the stack(s) present in $PWD and injects the matching STACK.md(s)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACK_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$PACK_ROOT/skills"
STACKS_DIR="$PACK_ROOT/stacks"
META_SKILL="$SKILLS_DIR/dev-using-agent-skills/SKILL.md"

# ── Stack detection ────────────────────────────────────────────────────────────

detected_stacks=()

detect_package_dep() {
  local dep="$1"
  find "$PWD" -maxdepth 3 -name "package.json" \
    ! -path "*/node_modules/*" \
    -exec grep -l "\"$dep\"" {} \; 2>/dev/null | head -1
}

# NestJS
if [ -n "$(detect_package_dep '@nestjs/core')" ]; then
  detected_stacks+=("nestjs")
fi

# Next.js (exclude angular and react-native false positives handled separately)
if [ -n "$(detect_package_dep 'next')" ] && \
   [ -z "$(detect_package_dep '@angular/core')" ] && \
   [ -z "$(detect_package_dep 'react-native')" ]; then
  detected_stacks+=("nextjs")
fi

# Angular
if [ -f "$PWD/angular.json" ] || [ -n "$(detect_package_dep '@angular/core')" ]; then
  detected_stacks+=("angular")
fi

# React Native
if [ -n "$(detect_package_dep 'react-native')" ]; then
  detected_stacks+=("react-native")
fi

# Spring Boot (pom.xml or build.gradle containing spring-boot)
if find "$PWD" -maxdepth 3 \( -name "pom.xml" -o -name "build.gradle" \) \
     ! -path "*/node_modules/*" 2>/dev/null | \
   xargs grep -l "spring-boot" 2>/dev/null | head -1 | grep -q .; then
  detected_stacks+=("spring-boot")
fi

# Go
if find "$PWD" -maxdepth 3 -name "go.mod" 2>/dev/null | head -1 | grep -q .; then
  detected_stacks+=("go")
fi

# Flutter
if find "$PWD" -maxdepth 3 -name "pubspec.yaml" 2>/dev/null | \
   xargs grep -l "flutter:" 2>/dev/null | head -1 | grep -q .; then
  detected_stacks+=("flutter")
fi

# ── Write plugin root path for skills to resolve agent_docs ───────────────────

mkdir -p "$PWD/.claude"
echo "$PACK_ROOT" > "$PWD/.claude/.avila-tek-root"

# ── Build message content ──────────────────────────────────────────────────────

meta_content=""
if [ -f "$META_SKILL" ]; then
  meta_content="$(cat "$META_SKILL")"
else
  meta_content="⚠️  dev-using-agent-skills/SKILL.md not found at $META_SKILL. Skill discovery is unavailable."
fi

stack_section=""
if [ ${#detected_stacks[@]} -gt 0 ]; then
  stack_section="---
## Stack Standards Loaded

Detected stacks: ${detected_stacks[*]}

Apply the matching standards throughout this session. Where multiple stacks are detected, all standards apply to their respective parts of the codebase.
"
  for stack in "${detected_stacks[@]}"; do
    stack_file="$STACKS_DIR/$stack/STACK.md"
    if [ -f "$stack_file" ]; then
      # Check if the stack is incomplete (Summary section still [PENDIENTE])
      if grep -A1 "^## Summary" "$stack_file" 2>/dev/null | grep -q "\[PENDIENTE\]"; then
        stack_section="${stack_section}
---
⚠️  Stack detected: $stack — standards are INCOMPLETE (all sections [PENDIENTE]).
Apply general best practices for this stack. Do NOT claim to follow Avila Tek $stack conventions.
To activate real standards: populate stacks/$stack/STACK.md and stacks/$stack/agent_docs/.
"
      else
        stack_section="${stack_section}
---
$(cat "$stack_file")
"
      fi
    fi
  done
else
  stack_section="---
## Stack Standards

No stack detected in the current directory. Continuing without stack-specific standards.
Open Claude Code from inside a project directory to load stack conventions automatically.
"
fi

# Build header with stack confirmation
if [ ${#detected_stacks[@]} -gt 0 ]; then
  stacks_label="${detected_stacks[*]}"
  header="✅ avila-tek-skill-pack hook ejecutado. Stack detectado: ${stacks_label}"
else
  header="✅ avila-tek-skill-pack hook ejecutado. No stack detectado."
fi

combined="${header}

${meta_content}

${stack_section}"

# ── Output via python3 (guarantees correct escaping for additionalContext) ────

if ! command -v python3 &>/dev/null; then
  # Fallback: plain text output (Claude Code injects stdout as context)
  printf '%s\n' "$combined"
  exit 0
fi

python3 -c "
import json, sys
msg = sys.stdin.read()
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': msg}}))
" <<< "$combined"
