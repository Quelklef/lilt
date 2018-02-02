
include hinterp

test(
    """
    alpha: <abcdefghijklmnopqrstuvwxyz>
    consonant: !<aeiou> $alpha
    consoWord: letters=*consonant *any
    """,
    "consoWord",
    "bhjdsjkeaklj",
    ~~ {
        "kind": "consoWord",
        "letters": "bhjdsjk"
    }
)
