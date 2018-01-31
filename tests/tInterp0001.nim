
include hinterp

test(
    """
    sentenceNode: sentence=sentence
    sentence: &word *[", " &word]
    word: val=*<abcdefghijklmnopqrstuvwxyz>
    """,
    "sentenceNode",
    "several, words, in, a, sentence",
    ~~ {
        "kind": "sentenceNode",
        "sentence": [
            {
                "kind": "word",
                "val": "several"
            },
            {
                "kind": "word",
                "val": "words"
            },
            {
                "kind": "word",
                "val": "in"
            },
            {
                "kind": "word",
                "val": "a"
            },
            {
                "kind": "word",
                "val": "sentence"
            }
        ]
    }
)
