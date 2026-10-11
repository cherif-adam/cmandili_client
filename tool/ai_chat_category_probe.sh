#!/usr/bin/env bash
# Amana Assistant — multi-catalogue probe.
#
# Two halves, because the fix has two halves:
#
#   RETRIEVAL  queries the real catalogues the way the app now does
#              (vendor_items JOIN vendors ON category) and reports how many
#              orderable items each of the 7 slugs actually has. Runs anytime.
#
#   PROMPT     asks the DEPLOYED ai-chat function one question per category,
#              plus a nutrition question, an off-topic one and one in Derja,
#              and prints the intent + service_category it routes to. This is
#              only meaningful AFTER deploying the function — before that it
#              reports the old food-only behaviour, which is the point: run it
#              once before and once after to see the change.
#
# Usage:  bash tool/ai_chat_category_probe.sh [retrieval|prompt|all]
# Reads SUPABASE_URL / SUPABASE_ANON_KEY from .env. Read-only: no writes, no
# orders, no deploy.

set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-all}"

URL=$(grep -E '^SUPABASE_URL=' .env | cut -d= -f2- | tr -d '\r"'"'"' ')
KEY=$(grep -E '^SUPABASE_ANON_KEY=' .env | cut -d= -f2- | tr -d '\r"'"'"' ')
if [ -z "$URL" ] || [ -z "$KEY" ]; then
  echo "SUPABASE_URL / SUPABASE_ANON_KEY missing from .env" >&2
  exit 1
fi

SLUGS="food grocery bakery flowers pets gifts electronics"

probe_retrieval() {
  echo "=== RETRIEVAL — orderable items per catalogue (open shops only) ==="
  printf '%-14s %8s  %s\n' "slug" "items" "example"
  for slug in $SLUGS; do
    curl -s "$URL/rest/v1/vendor_items?select=name,price,vendors!inner(name,is_open)&vendors.category=eq.$slug&is_available=eq.true&limit=200" \
      -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
    | python -c "
import sys, json
slug = sys.argv[1]
try:
    rows = json.load(sys.stdin)
except Exception:
    print(f'{slug:14} {\"ERR\":>8}'); raise SystemExit
rows = [r for r in rows if r.get('vendors', {}).get('is_open')]
ex = f\"{rows[0]['name']} ({rows[0]['vendors']['name']})\" if rows else '— empty —'
print(f'{slug:14} {len(rows):8}  {ex}')
" "$slug"
  done
  echo
}

ask() { # $1 = label, $2 = question
  local out
  out=$(curl -s -X POST "$URL/functions/v1/ai-chat" \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d "$(python -c 'import json,sys; print(json.dumps({"text": sys.argv[1], "history": []}))' "$2")")
  printf '%s' "$out" | python -c "
import sys, json
label = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    print(f'  {label:13} PARSE ERROR'); raise SystemExit
if 'error' in d:
    print(f\"  {label:13} ERROR {str(d.get('error'))[:60]}\"); raise SystemExit
print(f\"  {label:13} intent={d.get('intent'):<17} service_category={str(d.get('service_category')):<12} {d.get('message','')[:58]}\")
" "$1"
}

probe_prompt() {
  echo "=== PROMPT — deployed ai-chat routing ==="
  echo "(before deploying the new prompt, the non-food rows are expected to"
  echo " show intent=general with the nutrition redirect — that is the bug)"
  echo
  echo "-- one request per catalogue --"
  ask flowers     "Je peux commander un bouquet de fleur"
  ask pets        "je peux acheter des produits d'animalerie ?"
  ask electronics "je cherche un chargeur de telephone"
  ask gifts       "un cadeau pour ma mère"
  ask bakery      "je veux un gâteau d'anniversaire"
  ask grocery     "il me faut du lait et du shampoing"
  ask food        "je veux une pizza thon"
  echo
  echo "-- specialisation, off-topic, Derja --"
  ask nutrition   "je fais un régime, qu'est-ce que je peux manger ?"
  ask off-topic   "quel temps fait-il à Kairouan ?"
  ask derja       "n7eb nechri zhour l omi"
  echo
}

probe_cards() {
  echo "=== CARDS — does each catalogue actually render cards? ==="
  echo "(replays the client's tiered query with the model's real keyword;"
  echo " a catalogue with stock must never come back with zero cards)"
  echo
  python -I "$(dirname "$0")/ai_chat_cards_check.py" "$URL" "$KEY"
}

case "$MODE" in
  retrieval) probe_retrieval ;;
  prompt)    probe_prompt ;;
  cards)     probe_cards ;;
  all)       probe_retrieval; probe_prompt; probe_cards ;;
  *) echo "usage: $0 [retrieval|prompt|cards|all]" >&2; exit 2 ;;
esac
