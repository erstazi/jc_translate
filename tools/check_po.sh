#!/bin/bash

POT="../locale/jc_translate.pot"

if [ ! -f "$POT" ]; then
    echo "ERROR: POT file not found: $POT"
    exit 1
fi

# Extract msgids from a PO/POT file.
get_msgids() {
    grep '^msgid "' "$1" \
        | sed 's/^msgid "//; s/"$//' \
        | grep -v '^$' \
        | sort -u
}

POT_TMP=$(mktemp)
trap 'rm -f "$POT_TMP" "$PO_TMP"' EXIT

get_msgids "$POT" > "$POT_TMP"

echo "========================================"
echo "POT: $POT"
echo "========================================"
echo "POT msgids: $(wc -l < "$POT_TMP")"
echo

FOUND=0
TOTAL_MISSING=0

for PO in ../locale/*.po; do
    [ "$PO" = "$POT" ] && continue
    [ -f "$PO" ] || continue

    FOUND=1

    PO_TMP=$(mktemp)
    get_msgids "$PO" > "$PO_TMP"

    echo "----------------------------------------"
    echo "$PO"
    echo "----------------------------------------"

    MISSING=$(comm -23 "$POT_TMP" "$PO_TMP")
    EXTRA=$(comm -13 "$POT_TMP" "$PO_TMP")

    if [ -z "$MISSING" ]; then
        MISSING_COUNT=0
        echo "Missing: NONE"
    else
        MISSING_COUNT=$(printf '%s\n' "$MISSING" | wc -l)
        TOTAL_MISSING=$((TOTAL_MISSING + MISSING_COUNT))

        echo "Missing msgids:"
        echo "$MISSING" | sed 's/^/  - /'
    fi

    if [ -z "$EXTRA" ]; then
        echo "Extra:   NONE"
    else
        echo "Extra msgids:"
        echo "$EXTRA" | sed 's/^/  + /'
    fi

    echo "POT:     $(wc -l < "$POT_TMP")"
    echo "PO:      $(wc -l < "$PO_TMP")"
    echo "Missing: $MISSING_COUNT"
    echo
done

if [ "$FOUND" -eq 0 ]; then
    echo "No .po files found."
    exit 1
fi

echo "========================================"
echo "Check complete."
echo "========================================"
echo "TOTAL MISSING MSGIDS: $TOTAL_MISSING"
echo "========================================"
