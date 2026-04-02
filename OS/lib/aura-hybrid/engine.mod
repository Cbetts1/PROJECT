CTXFILE="$OS_ROOT/proc/aura/context/window"
MEMINDEX="$OS_ROOT/etc/aura/memory.index"
SEMINDEX="$OS_ROOT/etc/aura/semantic.index"

# Append to rolling context window
ctx_add() {
    echo "$*" >> "$CTXFILE"
    # keep last 50 lines
    tail -n 50 "$CTXFILE" > "$CTXFILE.tmp"
    mv "$CTXFILE.tmp" "$CTXFILE"
}

# Retrieve context window
ctx_get() {
    cat "$CTXFILE"
}

# Hybrid recall: combine symbolic + semantic + context
hybrid_recall() {
    query="$*"

    echo "[hybrid] Query: $query"
    echo

    echo "[hybrid] Context matches:"
    grep -i "$query" "$CTXFILE" 2>/dev/null | head -5
    echo

    echo "[hybrid] Symbolic matches:"
    grep -i "$query" "$MEMINDEX" 2>/dev/null | head -5
    echo

    echo "[hybrid] Semantic matches:"
    # compute semantic similarity
    qemb=$(embed_text "$query")
    while IFS='|' read -r key file emb; do
        case "$key" in ""|\#*) continue ;; esac
        dist=$(embed_distance "$qemb" "$emb")
        echo "$dist | $key"
    done < "$SEMINDEX" | sort -n | head -5
}

# Weighted recall: context > semantic > symbolic
hybrid_best() {
    query="$*"

    # 1. Context match?
    ctx=$(grep -i "$query" "$CTXFILE" | head -1)
    [ -n "$ctx" ] && { echo "$ctx"; return; }

    # 2. Semantic best match
    qemb=$(embed_text "$query")
    best=$(while IFS='|' read -r key file emb; do
        case "$key" in ""|\#*) continue ;; esac
        dist=$(embed_distance "$qemb" "$emb")
        echo "$dist | $key"
    done < "$SEMINDEX" | sort -n | head -1 | awk -F'|' '{print $2}' | xargs)

    [ -n "$best" ] && { semantic_get "$best"; return; }

    # 3. Symbolic fallback
    grep -i "$query" "$MEMINDEX" | head -1
}
