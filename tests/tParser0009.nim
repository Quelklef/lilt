
include hparser

test(
    """ex: "\t\r\c\l\a\b\e\\" """,
    newProgram(@[
        "ex" := ^"\t\r\c\l\a\b\e\\"
    ])
)
