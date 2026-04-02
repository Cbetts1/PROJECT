embed_text() {
    text="$*"
    # Produce a 5-dimensional pseudo-embedding using hashing
    e1=$(( $(echo "$text" | md5sum | cut -c1-8) % 1000 ))
    e2=$(( $(echo "$text" | md5sum | cut -c9-16) % 1000 ))
    e3=$(( $(echo "$text" | md5sum | cut -c17-24) % 1000 ))
    e4=$(( $(echo "$text" | md5sum | cut -c25-32) % 1000 ))
    e5=$(( (e1 + e2 + e3 + e4) % 1000 ))
    echo "$e1,$e2,$e3,$e4,$e5"
}

embed_distance() {
    a="$1"
    b="$2"
    IFS=',' read -r a1 a2 a3 a4 a5 <<EOF2
$a
EOF2
    IFS=',' read -r b1 b2 b3 b4 b5 <<EOF3
$b
EOF3
    # Manhattan distance
    echo $(( 
        (${a1}-${b1#-})>=0?${a1}-${b1#-}:${b1#-}-${a1} +
        (${a2}-${b2#-})>=0?${a2}-${b2#-}:${b2#-}-${a2} +
        (${a3}-${b3#-})>=0?${a3}-${b3#-}:${b3#-}-${a3} +
        (${a4}-${b4#-})>=0?${a4}-${b4#-}:${b4#-}-${a4} +
        (${a5}-${b5#-})>=0?${a5}-${b5#-}:${b5#-}-${a5}
    ))
}
