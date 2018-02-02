
include hinterp

#[
Test recursion
]#

test(
    """
    r: "a" ?r
    n: v=r
    """,
    "n",
    "aaaaa",
    ~~ {
        "kind": "n",
        "v": "aaaaa"
    }
)
