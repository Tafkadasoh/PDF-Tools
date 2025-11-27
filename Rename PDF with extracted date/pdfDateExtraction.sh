#!/usr/bin/env zsh
export PATH="/opt/homebrew/bin:$PATH"

set -o nounset
set -o pipefail

typeset -A months
months=(
  januar 01 februar 02 märz 03 maerz 03
  april 04 mai 05 juni 06
  juli 07 august 08 september 09
  oktober 10 november 11 dezember 12
)

# --- Optionen ---
verbose=false
if [[ "$1" == "-v" ]]; then
  verbose=true
  shift
fi

normalize_date() {
  local t="$1"
  local y m d monthname

  # dd.mm.yyyy
  if [[ "$t" =~ (^|[[:space:][:punct:]])([0-3]?[0-9])\.([0-1]?[0-9])\.((1[0-9]{3}|2[0-9]{3}))([[:space:][:punct:]]|$) ]]; then
    d="${match[2]}" m="${match[3]}" y="${match[4]}"
    printf "%04d-%02d-%02d\n" "$y" "$m" "$d"
    return 0
  fi

  # yyyy-mm-dd
  if [[ "$t" =~ (^|[[:space:][:punct:]])((1[0-9]{3}|2[0-9]{3}))-([0-1][0-9])-([0-3][0-9])([[:space:][:punct:]]|$) ]]; then
    y="${match[2]}" m="${match[3]}" d="${match[4]}"
    printf "%s-%s-%s\n" "$y" "$m" "$d"
    return 0
  fi

  # "4. September 2024"
  if [[ "$t" =~ (^|[[:space:][:punct:]])([0-3]?[0-9])\.[[:space:]]*([A-Za-zÄÖÜäöü]+)[[:space:]]+((1[0-9]{3}|2[0-9]{3}))([[:space:][:punct:]]|$) ]]; then
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
    [[ -n "$m" ]] && printf "%04d-%02d-%02d\n" "$y" "$m" "$d" && return 0
  fi

  # month + year only
  if [[ "$t" =~ (^|[[:space:][:punct:]])([A-Za-zÄÖÜäöü]+)[[:space:]]+((1[0-9]{3}|2[0-9]{3}))([[:space:][:punct:]]|$) ]]; then
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
    [[ -n "$m" ]] && printf "%04d-%02d\n" "$y" "$m" && return 0
  fi
  return 1
}

closest_date() {
  local -a arr=("$@")
  local today=$(date +%s)
  local best="" bestdiff=999999999

  for d in $arr; do
    local ts=""
    local display="$d"

    if [[ "$d" =~ ^[12][0-9]{3}-[0-9]{2}-[0-9]{2}$ ]]; then
      ts=$(date -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null || echo "")
    elif [[ "$d" =~ ^[12][0-9]{3}-[0-9]{2}$ ]]; then
      ts=$(date -j -f "%Y-%m-%d" "${d}-01" +%s 2>/dev/null || echo "")
      display="$d"   # nur YYYY-MM für spätere Ausgabe
    fi

    if [[ -n "$ts" ]]; then
      local diff=$(( ts > today ? ts - today : today - ts ))
      if (( diff < bestdiff )); then
        best="$display"
        bestdiff=$diff
      fi
    fi
  done

  echo "$best"
}

debug_dates() {
  local -a arr=("$@")
  if $verbose; then
    echo ">>> Gefundene Daten:"
    for d in $arr; do
      echo "   $d"
    done
  fi
}

# --- Main loop ---
for pdf in "$@"; do
  [[ ! -f "$pdf" ]] && echo "File not found: $pdf" >&2 && continue

  text="$(pdftotext "$pdf" - 2>/dev/null)"
  text="${text//$'\n'/ }"
  text="${text//-\ /}"

  dates=()
  tokens=(${(z)text})

  for i in {1..${#tokens}}; do
    # Einzelnes Token
    if d=$(normalize_date "${tokens[i]}"); then
      dates+=$d
    fi
    # Kombination aus zwei Tokens
    if (( i < ${#tokens} )); then
      if d=$(normalize_date "${tokens[i]} ${tokens[i+1]}"); then
        dates+=$d
      fi
    fi
    # Kombination aus drei Tokens
    if (( i < ${#tokens}-1 )); then
      if d=$(normalize_date "${tokens[i]} ${tokens[i+1]} ${tokens[i+2]}"); then
        dates+=$d
      fi
    fi
  done

  debug_dates "${dates[@]}"

  if [[ ${#dates[@]} -gt 0 ]]; then
    date=$(closest_date $dates)
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
  else
    echo "No valid date found in $pdf"
  fi
done
