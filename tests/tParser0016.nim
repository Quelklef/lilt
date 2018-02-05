
include hparser

# Test single-quoted literals

test(
    "sql: 'a'",
    newProgram(@[
        "sql" := ^"a"
    ])
)
