
include hinterp

#[
Ensure that definitions override existing definitions
]#

test(
    """
    l: <abc>
    l: <def>
    l: <geh>
    n: v=l
    """,
    "n",
    "e",
    ~~ {
        "kind": "n",
        "v": "e"
    }
)
