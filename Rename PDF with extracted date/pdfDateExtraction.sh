#!/usr/bin/env zsh
# Activate for Automator only
# export PATH="/opt/homebrew/bin:$PATH"

set -o nounset
set -o pipefail

typeset -A months
months=(
  januar 01 februar 02 märz 03 maerz 03
  april 04 mai 05 juni 06
  juli 07 august 08 september 09
  oktober 10 november 11 dezember 12
)

normalize_date() {
  local t="$1"
  local y m d monthname

  # dd.mm.yyyy
  if [[ "$t" =~ (^|[^0-9])([0-3]?[0-9])\.([0-1]?[0-9])\.([1-2][0-9]{3})([^0-9]|$) ]]; then
    d="${match[2]}" m="${match[3]}" y="${match[4]}"
    if (( 1 <= 10#$m && 10#$m <= 12 && 1 <= 10#$d && 10#$d <= 31 )); then
      printf "%04d-%02d-%02d\n" "$y" "$m" "$d"
      return 0
    fi
  fi

  # yyyy-mm-dd
  if [[ "$t" =~ (^|[^0-9])([1-2][0-9]{3})-([0-1][0-9])-([0-3][0-9])([^0-9]|$) ]]; then
    y="${match[2]}" m="${match[3]}" d="${match[4]}"
    if (( 1 <= 10#$m && 10#$m <= 12 && 1 <= 10#$d && 10#$d <= 31 )); then
      printf "%s-%s-%s\n" "$y" "$m" "$d"
      return 0
    fi
  fi
  # "4. September 2024"
  if [[ "$t" =~ (^|[^0-9])([0-3]?[0-9])\.[[:space:]]*([A-Za-zÄÖÜäöü]+)[[:space:]]+([1-2][0-9]{3})([^0-9]|$) ]]; then
    d="${match[2]}" monthname="${match[3]:l}" y="${match[4]}"
    m=""
    if [[ -n "${months[$monthname]-}" ]]; then
      m="${months[$monthname]}"
    else
      for key in ${(k)months}; do
        if [[ "$monthname" == *"$key"* || "$key" == *"$monthname"* ]]; then
          m="${months[$key]}"
          break
        fi
      done
    fi
    if [[ -n "$m" && 1 -le 10#$d && 10#$d -le 31 ]]; then
      printf "%04d-%02d-%02d\n" "$y" "$m" "$d"
      return 0
    fi
  fi
  # --- (month + year only), e.g. "April 2025" ---
  if [[ "$t" =~ (^|[^0-9])([A-Za-zÄÖÜäöü]+)[[:space:]]+([1-2][0-9]{3})([^0-9]|$) ]]; then
    monthname="${match[2]:l}" y="${match[3]}"
    m=""
    if [[ -n "${months[$monthname]-}" ]]; then
      m="${months[$monthname]}"
    else
      for key in ${(k)months}; do
        if [[ "$monthname" == *"$key"* || "$key" == *"$monthname"* ]]; then
          m="${months[$key]}"
          break
        fi
      done
    fi
    if [[ -n "$m" ]]; then
      printf "%04d-%02d\n" "$y" "$m"
      return 0
    fi
  fi
  return 1
}


# --- Main loop over all arguments ---
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <pdf-file> [<pdf-file> ...]" >&2
  exit 1
fi

if ! command -v pdftotext >/dev/null; then
  echo "pdftotext not found in PATH: $PATH" >&2
fi

for pdf in "$@"; do
  if [[ ! -f "$pdf" ]]; then
    echo "File not found: $pdf" >&2
    continue
  fi

  text="$(pdftotext "$pdf" - 2>/dev/null)"
  text="${text//$'\n'/ }"
  text="${text//-\ /}"

  date="$(normalize_date "$text" || true)"

  if [[ -n "$date" ]]; then
    dir=$(dirname "$pdf")
    base=$(basename "$pdf" .pdf)
    ext="${pdf##*.}"
    newname="${dir}/${date} - ${base}.${ext}"
    mv -- "$pdf" "$newname"
    echo "Renamed to $newname"
  else
    echo "No valid date found in $pdf"
  fi
done
