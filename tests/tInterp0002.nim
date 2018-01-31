
include hinterp

test(
    """
    alpha: <abcdefghijklmnopqrstuvwxyz>
    consonant: !<aeiou> $alpha
    consoWord: letters=*consonant
    """,
    "consoWord",
    "bhjdsjkeaklj",
    ~~ {
        "kind": "consoWord",
        "letters": "bhjdsjk"
    }
)
