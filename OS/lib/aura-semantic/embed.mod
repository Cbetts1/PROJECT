embed_text() {
    text="$*"
    e1=$(printf '%s'  "$text"   | cksum | awk '{print $1 % 1000}')
    e2=$(printf '%sA' "$text"   | cksum | awk '{print $1 % 1000}')
    e3=$(printf '%sB' "$text"   | cksum | awk '{print $1 % 1000}')
    e4=$(printf '%sC' "$text"   | cksum | awk '{print $1 % 1000}')
    e5=$(printf '%sD' "$text"   | cksum | awk '{print $1 % 1000}')
    echo "$e1,$e2,$e3,$e4,$e5"
}

embed_distance() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        n = split(a, av, ",")
        split(b, bv, ",")
        d = 0
        for (i = 1; i <= n; i++) {
            v = av[i] - bv[i]
            d += (v < 0 ? -v : v)
        }
        print d
    }'
}
