
include hinterp

#[

TODO: Fix this.

This issue is a bit suble.
The issue is that having `addOperation` be the first reference in the
choice `expr` and having `addOperation` immediately call expr is that
the parser will infinitely loop.
However, if `expr` starts with `reference`, then parsing "x + y" with
`expr` will return `reference` "x" rather than `addOperation` "x + y".

Dunno how to fix this.

]#

test("""

    prog: statements={ _ *[_ &statement _] _ }

    / Implement "return"
    statement: innerNode=[functionCall | assignment] _ ";"

    functionCall: target=identifier _ "(" _ body=expr _ ")"
    assignment: "let" _ varName=identifier _ "=" _ value=expr

    identifier: alpha *alphanum

    expr: addOperation | reference | intLiteral

    reference: target=identifier
    addOperation: leftValue=expr _ "+" _ rightValue=expr
    intLiteral: val=+digit
    
    """,
    "prog",
    """
    
    let x = 1;
    let y = 2;

    echo(x + y);
    
    """,
    ~~ {
        "kind": "prog",
        "statements": [
            {
                "kind": "statement",
                "innerNode": {
                    "kind": "assignment",
                    "varName": "x",
                    "value": {
                        "kind": "intLiteral",
                        "val": "1"
                    }
                }
            },
            {
                "kind": "statement",
                "innerNode": {
                    "kind": "assignment",
                    "varName": "y",
                    "value": {
                        "kind": "intLiteral",
                        "val": "2"
                    }
                }
            },
            {
                "kind": "statement",
                "innerNode": {
                    "kind": "functionCall",
                    "target": "echo",
                    "body": {
                        "kind": "addOperation",
                        "leftValue": {
                            "kind": "reference",
                            "target": "x"
                        },
                        "rightValue": {
                            "kind": "reference",
                            "target": "y"
                        }
                    }
                }
            }
        ]
    }
)
