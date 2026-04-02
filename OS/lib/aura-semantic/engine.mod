SEMROOT="$OS_ROOT/proc/aura/semantic"
SEMINDEX="$OS_ROOT/etc/aura/semantic.index"

semantic_store() {
    key="$1"; shift
    text="$*"
    file=$(echo "$key" | tr '.' '_').sem

    # Save raw text
    echo "$text" > "$SEMROOT/$file"

    # Compute embedding
    emb=$(embed_text "$text")

    # Update index
    grep -v "^$key " "$SEMINDEX" > "$SEMINDEX.tmp" 2>/dev/null
    echo "$key | $file | $emb" >> "$SEMINDEX.tmp"
    mv "$SEMINDEX.tmp" "$SEMINDEX"
}

semantic_get() {
    key="$1"
    file=$(grep "^$key " "$SEMINDEX" | awk -F'|' '{print $2}' | xargs)
    [ -z "$file" ] && { echo "(no semantic memory)"; return; }
    cat "$SEMROOT/$file"
}

semantic_search() {
    query="$*"
    qemb=$(embed_text "$query")

    while IFS='|' read -r key file emb; do
        case "$key" in ""|\#*) continue ;; esac
        dist=$(embed_distance "$qemb" "$emb")
        echo "$dist | $key | $file"
    done < "$SEMINDEX" | sort -n | head -10
}

semantic_delete() {
    key="$1"
    file=$(grep "^$key " "$SEMINDEX" | awk -F'|' '{print $2}' | xargs)
    [ -n "$file" ] && rm -f "$SEMROOT/$file"
    grep -v "^$key " "$SEMINDEX" > "$SEMINDEX.tmp"
    mv "$SEMINDEX.tmp" "$SEMINDEX"
}

semantic_list() {
    cat "$SEMINDEX"
}
