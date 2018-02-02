
include hinterp

test(
    """
    digit: <1234567890>
    letter: <abcdefghijklmnopqrstuvwxyz>
    alphanumeric: digit | letter
    anstring: *alphanumeric
    annode: val=anstring *any
    """,
    "annode",
    "qwnjgib2723t99 12h8t9",
    ~~ {
        "kind": "annode",
        "val": "qwnjgib2723t99"
    }
)
