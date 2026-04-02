MEMROOT="$OS_ROOT/proc/aura/memory"
MEMINDEX="$OS_ROOT/etc/aura/memory.index"

mem_set() {
    key="$1"; shift
    val="$*"
    file=$(echo "$key" | tr '.' '_').mem
    echo "$val" > "$MEMROOT/$file"

    # update index
    grep -v "^$key " "$MEMINDEX" > "$MEMINDEX.tmp" 2>/dev/null
    echo "$key | $file | " >> "$MEMINDEX.tmp"
    mv "$MEMINDEX.tmp" "$MEMINDEX"
}

mem_get() {
    key="$1"
    file=$(grep "^$key " "$MEMINDEX" | awk -F'|' '{print $2}' | xargs)
    [ -z "$file" ] && { echo "(no memory)"; return; }
    cat "$MEMROOT/$file"
}

mem_search() {
    pattern="$1"
    grep -i "$pattern" "$MEMINDEX"
}

mem_delete() {
    key="$1"
    file=$(grep "^$key " "$MEMINDEX" | awk -F'|' '{print $2}' | xargs)
    [ -n "$file" ] && rm -f "$MEMROOT/$file"
    grep -v "^$key " "$MEMINDEX" > "$MEMINDEX.tmp"
    mv "$MEMINDEX.tmp" "$MEMINDEX"
}

mem_tag() {
    key="$1"; shift
    tags="$*"
    file=$(grep "^$key " "$MEMINDEX" | awk -F'|' '{print $2}' | xargs)
    [ -z "$file" ] && return
    grep -v "^$key " "$MEMINDEX" > "$MEMINDEX.tmp"
    echo "$key | $file | $tags" >> "$MEMINDEX.tmp"
    mv "$MEMINDEX.tmp" "$MEMINDEX"
}

mem_list() {
    cat "$MEMINDEX"
}
