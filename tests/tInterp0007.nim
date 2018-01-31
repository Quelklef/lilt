
include hinterp

test(
    """
    identifier: *<abcdefghijklmnopqrstuvwxyz>
    arg: id=identifier
    funcDecl: "func " id=identifier "(" args={ &arg *[", " &arg] } ");"
    """,
    "funcDecl",
    "func pow(a, b);",
    ~~ {
        "kind": "funcDecl",
        "id": "pow",
        "args": [
            {
                "kind": "arg",
                "id": "a"
            },
            {
                "kind": "arg",
                "id": "b"
            }
        ]
    }
)
