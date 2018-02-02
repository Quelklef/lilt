
include hinterp

test(
    """
    vowel: <aeiou>
    vowels: *$vowel
    nVowels: val=vowels *any
    """,
    "nVowels",
    "aeeoouuiaobbbbboisoso",
    ~~ {
        "kind": "nVowels",
        "val": "aeeoouuiao"
    }
)
