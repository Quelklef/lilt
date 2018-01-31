
include hparser

test(
    """
    char: *<abcdefg>
    string: +char
    """,
    newProgram(@[
        "char" := * <>"abcdefg"
        , "string" := + @"char"
    ])
)
