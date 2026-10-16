#!/usr/bin/env bash
# Fail when a Material button API is used outside the three theme components.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

allow_re='lib/design_system/widgets/loading_button\.dart|lib/design_system/theme/button_themes\.dart'
pattern='ElevatedButton|OutlinedButton|TextButton|FilledButton|ButtonStyle|styleFrom'
check_allow='lib/design_system/widgets/mutation_check\.dart'
check_pattern='\\b(Checkbox|Switch|CheckboxListTile|SwitchListTile)\\b'

scan() {
  local expr="$1"
  local allow="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -n --glob '*.dart' -e "$expr" lib | rg -v -e "$allow" || true
  else
    grep -R -n -E "$expr" lib --include='*.dart' | grep -E -v "$allow" || true
  fi
}

hits="$(scan "$pattern" "$allow_re")"
if [[ -n "$hits" ]]; then
  echo "Button APIs found outside the theme components:"
  echo "$hits"
  exit 1
fi

check_hits="$(scan "$check_pattern" "$check_allow")"
if [[ -n "$check_hits" ]]; then
  echo "Checkable controls found outside MutationCheckbox/MutationSwitch:"
  echo "$check_hits"
  exit 1
fi

echo "Button guard: no ElevatedButton/OutlinedButton/TextButton/FilledButton/ButtonStyle/styleFrom outside the theme components."
echo "Checkable guard: no Checkbox/Switch/CheckboxListTile/SwitchListTile outside MutationCheckbox/MutationSwitch."
