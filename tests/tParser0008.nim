
include hparser

test(
    """ex: <\>>""",
    newProgram(@[
        "ex" := <>">"
    ])
)
