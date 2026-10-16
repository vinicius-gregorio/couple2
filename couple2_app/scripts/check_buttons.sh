#!/usr/bin/env bash
# Fail when a Material button API is used outside the three theme components.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

allow_re='lib/design_system/widgets/loading_button\.dart|lib/design_system/theme/button_themes\.dart'
pattern='ElevatedButton|OutlinedButton|TextButton|FilledButton|ButtonStyle|styleFrom'
check_allow='lib/design_system/widgets/mutation_check\.dart'
# One backslash so rg sees a word boundary, not the two-character text \b.
check_pattern='\b(Checkbox|Switch|CheckboxListTile|SwitchListTile)\b'
tap_allow='lib/design_system/widgets/loading_button\.dart|lib/design_system/widgets/app_fab\.dart|lib/design_system/widgets/app_icon_button\.dart|lib/design_system/widgets/app_ink_well\.dart|lib/modules/auth/ui/widgets/google_sign_in_button\.dart|lib/modules/auth/ui/widgets/apple_sign_in_button\.dart'
# Negative lookbehind so AppIconButton and LoadingIconButton stay legal.
tap_pattern='(?<![A-Za-z])(IconButton|FloatingActionButton|InkWell|GestureDetector)\('
error_file='lib/design_system/widgets/async_body.dart'
error_pattern='OverlayPortal|OverlayEntry|\bOverlay\b|\bPositioned\b|\bStack\b'
overlay_pattern='OverlayPortal|OverlayEntry|\bOverlay\b'

# rg's default engine rejects lookbehind. --pcre2 is required, and a
# parse error (exit 2) must fail the guard instead of looking like a clean tree.
scan() {
  local expr="$1"
  local allow="$2"
  local out status
  if command -v rg >/dev/null 2>&1; then
    set +e
    out="$(rg --pcre2 -n --glob '*.dart' -e "$expr" lib)"
    status=$?
    set -e
    if [[ "$status" -eq 2 ]]; then
      echo "rg failed while scanning: $expr" >&2
      exit 1
    fi
    if [[ "$status" -eq 0 ]]; then
      printf '%s\n' "$out" | rg -v -e "$allow" || true
    fi
  elif echo | grep -P -q . >/dev/null 2>&1; then
    grep -R -n -P "$expr" lib --include='*.dart' | grep -E -v "$allow" || true
  else
    echo "rg with PCRE2 is required for the tap guard." >&2
    exit 1
  fi
}

failed=0

hits="$(scan "$pattern" "$allow_re")"
if [[ -n "$hits" ]]; then
  echo "Button APIs found outside the theme components:"
  echo "$hits"
  failed=1
fi

check_hits="$(scan "$check_pattern" "$check_allow")"
if [[ -n "$check_hits" ]]; then
  echo "Checkable controls found outside MutationCheckbox/MutationSwitch:"
  echo "$check_hits"
  failed=1
fi

tap_hits="$(scan "$tap_pattern" "$tap_allow")"
if [[ -n "$tap_hits" ]]; then
  echo "IconButton/FAB/InkWell/GestureDetector found outside the theme components:"
  echo "$tap_hits"
  failed=1
fi

if command -v rg >/dev/null 2>&1; then
  set +e
  overlay_hits="$(rg --pcre2 -n --glob '*.dart' -e "$overlay_pattern" lib)"
  overlay_status=$?
  set -e
  if [[ "$overlay_status" -eq 2 ]]; then
    echo "rg failed while scanning overlays" >&2
    exit 1
  fi
  if [[ "$overlay_status" -ne 0 ]]; then
    overlay_hits=""
  fi
else
  overlay_hits="$(grep -R -n -E "$overlay_pattern" lib --include='*.dart' || true)"
fi
if [[ -n "$overlay_hits" ]]; then
  echo "Overlay error painting found in lib:"
  echo "$overlay_hits"
  failed=1
fi

if command -v rg >/dev/null 2>&1; then
  set +e
  error_hits="$(rg --pcre2 -n -e "$error_pattern" "$error_file")"
  error_status=$?
  set -e
  if [[ "$error_status" -eq 2 ]]; then
    echo "rg failed while scanning $error_file" >&2
    exit 1
  fi
  if [[ "$error_status" -ne 0 ]]; then
    error_hits=""
  fi
else
  error_hits="$(grep -n -E "$error_pattern" "$error_file" || true)"
fi
if [[ -n "$error_hits" ]]; then
  echo "Error banner paints over content ($error_file):"
  echo "$error_hits"
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "Button guard: no ElevatedButton/OutlinedButton/TextButton/FilledButton/ButtonStyle/styleFrom outside the theme components."
echo "Checkable guard: no Checkbox/Switch/CheckboxListTile/SwitchListTile outside MutationCheckbox/MutationSwitch."
echo "Tap guard: no IconButton/FloatingActionButton/InkWell/GestureDetector outside the theme components."
echo "Error-banner guard: no Overlay/Positioned/Stack in the error widget, and no Overlay in lib."
