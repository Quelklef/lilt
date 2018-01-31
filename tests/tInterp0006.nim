
include hinterp

test(
    """
    nBanana: val="banana"
    nApple: val="apple"
    nFruit: nBanana | nApple
    """,
    "nFruit",
    "banana",
    ~~ {
        "kind": "nBanana",
        "val": "banana"
    }
)
