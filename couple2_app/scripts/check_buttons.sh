#!/usr/bin/env bash
# Fail when a Material button API is used outside the three theme components.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

allow_re='lib/design_system/widgets/loading_button\.dart|lib/design_system/theme/button_themes\.dart'
pattern='ElevatedButton|OutlinedButton|TextButton|FilledButton|ButtonStyle|styleFrom'

if command -v rg >/dev/null 2>&1; then
  hits="$(rg -n --glob '*.dart' -e "$pattern" lib \
    | rg -v -e "$allow_re" || true)"
else
  hits="$(grep -R -n -E "$pattern" lib --include='*.dart' \
    | grep -E -v "$allow_re" || true)"
fi

if [[ -n "$hits" ]]; then
  echo "Button APIs found outside the theme components:"
  echo "$hits"
  exit 1
fi

echo "Button guard: no ElevatedButton/OutlinedButton/TextButton/FilledButton/ButtonStyle/styleFrom outside the theme components."
