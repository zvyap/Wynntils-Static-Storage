#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)"
RAW_FILE="$BASE_DIR/Data-Storage/raw/content/content_book_dump.json"
TARGET="$BASE_DIR/Reference/content_book.json"
URLS_FILE="$BASE_DIR/Data-Storage/urls.json"
NODE_BIN="${NODE_BIN:-node}"

if ! command -v "$NODE_BIN" >/dev/null 2>&1; then
    if [ -x "/c/Program Files/nodejs/node.exe" ]; then
        NODE_BIN="/c/Program Files/nodejs/node.exe"
    elif [ -x "/mnt/c/Program Files/nodejs/node.exe" ]; then
        NODE_BIN="/mnt/c/Program Files/nodejs/node.exe"
    else
        echo "Error: node is required to generate the content book index" >&2
        exit 1
    fi
fi

node_path() {
    local path="$1"
    if [[ "$path" =~ ^/mnt/([a-zA-Z])/(.*)$ ]]; then
        local drive="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"
        echo "${drive^^}:/$rest"
    elif [[ "$path" =~ ^/([a-zA-Z])/(.*)$ ]]; then
        local drive="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"
        echo "${drive^^}:/$rest"
    else
        echo "$path"
    fi
}

if [ ! -f "$RAW_FILE" ]; then
    echo "Error: raw content book dump not found at $RAW_FILE" >&2
    exit 1
fi

if [ ! -f "$URLS_FILE" ]; then
    echo "Error: urls.json not found at $URLS_FILE" >&2
    exit 1
fi

"$NODE_BIN" - "$(node_path "$RAW_FILE")" "$(node_path "$TARGET.tmp")" <<'NODE'
const fs = require("fs");

const [rawFile, targetFile] = process.argv.slice(2);
const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8").replace(/^\uFEFF/, ""));
const raw = readJson(rawFile);
const categoryOrder = [
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
];

const contentBook = categoryOrder.map((category) => ({
  category,
  activities: raw[category] ?? [],
}));

fs.writeFileSync(targetFile, `${JSON.stringify(contentBook, null, 2)}\n`, "utf8");
NODE

mv "$TARGET.tmp" "$TARGET"

MD5=$(md5sum "$TARGET" | cut -d' ' -f1)

"$NODE_BIN" - "$(node_path "$URLS_FILE")" "$(node_path "$URLS_FILE.tmp")" "$MD5" <<'NODE'
const fs = require("fs");

const [urlsFile, targetFile, md5] = process.argv.slice(2);
const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8").replace(/^\uFEFF/, ""));
const urls = readJson(urlsFile);
const contentBookUrl = {
  id: "dataStaticContentBook",
  md5,
  path: "Reference/content_book.json",
  url: "https://cdn.wynntils.com/static/Reference/content_book.json",
};

const existingIndex = urls.findIndex((entry) => entry.id === contentBookUrl.id);
if (existingIndex === -1) {
  urls.push(contentBookUrl);
} else {
  urls[existingIndex] = { ...urls[existingIndex], ...contentBookUrl };
}

fs.writeFileSync(targetFile, `${JSON.stringify(urls, null, 2)}\n`, "utf8");
NODE

mv "$URLS_FILE.tmp" "$URLS_FILE"
