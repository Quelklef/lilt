
include hinterp

test("""
    prog: statements={ _ *[_ &statement _] _ }

    / Implement "return"
    statement: innerNode=[functionCall | assignment] _ ";"

    functionCall: target=identifier _ "(" _ body=expr _ ")"
    assignment: "let" _ varName=identifier _ "=" _ value=expr

    identifier: alpha *alphanum

    expr: intLiteral | addOperation | reference

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
