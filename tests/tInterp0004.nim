
include hinterp

test(
    """
    tIdentif: +<abcdefghijklmnopqrstuvwxyz>
    nArg: id=tIdentif
    lArgs: ?&nArg *[", " &nArg]
    nFuncdef: "function " id=tIdentif "(" args=lArgs ");"
    """,
    "nFuncdef",
    "function multiply(argone, argtwo, argthree);",
    ~~ {
        "kind": "nFuncdef",
        "id": "multiply",
        "args": [
            {
                "kind": "nArg",
                "id": "argone"
            },
            {
                "kind": "nArg",
                "id": "argtwo"
            },
            {
                "kind": "nArg",
                "id": "argthree"
            }
        ]
    }
)
