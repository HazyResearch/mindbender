tmpdir=$(mktemp -d "$BATS_TMPDIR"/merge-order-specs.XXXXXXX)
trap 'cd; rm -rf "$tmpdir"' EXIT
cd "$tmpdir"

@test "merge two input without wildcard" {
    {
        seq 10
    } >a
    {
        seq 11 20
    } >b
    {
        seq 20
        echo '*'
    } >expected
    merge-order-specs a b
    diff -u expected a
}

@test "merge into wildcard at middle" {
    {
        seq 10
        echo '*'
        seq 21 30
    } >a
    {
        seq 11 20
    } >b
    {
        seq 20
        echo '*'
        seq 21 30
    } >expected
    merge-order-specs a b
    diff -u expected a
}

@test "merge into wildcard at top" {
    {
        echo '*'
        seq 21 30
    } >a
    {
        seq 11 20
    } >b
    {
        seq 11 20
        echo '*'
        seq 21 30
    } >expected
    merge-order-specs a b
    diff -u expected a
}

@test "merge into wildcard at bottom" {
    {
        seq 10
        echo '*'
    } >a
    {
        seq 11 20
    } >b
    {
        seq 20
        echo '*'
    } >expected
    merge-order-specs a b
    diff -u expected a
}

@test "merge more than two" {
    {
        seq 10
        echo '*'
    } >a
    {
        echo '*'
        seq 41 50
    } >b
    {
        seq 11 20
    } >c
    {
        seq 21 30
        echo '*'
    } >d
    {
        seq 31 40
    } >e
    {
        seq 40
        echo '*'
        seq 41 50
    } >expected
    merge-order-specs a b c d e
    diff -u expected a
}
