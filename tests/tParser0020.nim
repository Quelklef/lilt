
include hparser

test(
    "x: 'a' 'b' | 'b' 'c' | 'c' 'd'",
    newProgram(@[
        "x" := |[
              ~[ ^"a", ^"b" ]
            , ~[ ^"b", ^"c" ]
            , ~[ ^"c", ^"d" ]
        ]
    ])
)
