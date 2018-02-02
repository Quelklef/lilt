
include hinterp

#[
Test redefining a rule based on the old definition
]#

test(
    """r: "rule"
r_: r
r: "-->" r_
n: v=r
""",
    "n",
    "-->rule",
    ~~ {
        "kind": "n",
        "v": "-->rule"
    }
)
