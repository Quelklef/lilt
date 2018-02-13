
include hparser

test(
    """
    test0: '\x00'
    testF: '\xFF'
    testG: '\x5E'
    """,
    newProgram(@[
          "test0" := ^"\x00"
        , "testF" := ^"\xFF"
        , "testG" := ^"\x5E"
    ])
)
