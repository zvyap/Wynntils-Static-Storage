#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)"
RAW_FILE="${1:-$BASE_DIR/Data-Storage/raw/content/content_book_dump.json}"
TARGET="$BASE_DIR/Reference/content_book.json"
URLS_FILE="$BASE_DIR/Data-Storage/urls.json"

if [ ! -f "$RAW_FILE" ]; then
    echo "Error: raw content book dump not found at $RAW_FILE" >&2
    exit 1
fi

if [ ! -f "$URLS_FILE" ]; then
    echo "Error: urls.json not found at $URLS_FILE" >&2
    exit 1
fi

python3 - "$RAW_FILE" "$TARGET.tmp" <<'PY'
import json
import sys

raw_file, target_file = sys.argv[1], sys.argv[2]

with open(raw_file, "r", encoding="utf-8-sig") as f:
  raw = json.load(f)

category_order = [
  "quest",
  "miniQuest",
  "worldEvent",
  "secretDiscovery",
  "worldDiscovery",
  "territorialDiscovery",
  "cave",
  "dungeon",
  "raid",
  "bossAltar",
  "lootrunCamp",
]

content_book = [
  {
    "category": category,
    "activities": raw.get(category, []),
  }
  for category in category_order
]

with open(target_file, "w", encoding="utf-8") as f:
  json.dump(content_book, f, indent=2)
  f.write("\n")
PY

mv "$TARGET.tmp" "$TARGET"

MD5=$(md5sum "$TARGET" | cut -d' ' -f1)

jq --arg md5 "$MD5" '
  . as $urls
  | ($urls | any(.[]; .id == "dataStaticContentBook")) as $has_entry
  | (
      map(
        if .id == "dataStaticContentBook" then
          . + {
            md5: $md5,
            path: "Reference/content_book.json",
            url: "https://cdn.wynntils.com/static/Reference/content_book.json"
          }
        else
          .
        end
      )
    ) as $updated
  | if $has_entry then
      $updated
    else
      $updated + [{
        id: "dataStaticContentBook",
        md5: $md5,
        path: "Reference/content_book.json",
        url: "https://cdn.wynntils.com/static/Reference/content_book.json"
      }]
    end
' "$URLS_FILE" > "$URLS_FILE.tmp"

mv "$URLS_FILE.tmp" "$URLS_FILE"
