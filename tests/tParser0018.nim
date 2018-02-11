
include hparser

test(
    "ex: '__' #{prop='val'} '__!'",
    newProgram(@[
        "ex" %= ~[ ^"__", /. % ("prop" .= ^"val"), ^"__!" ]
    ])
)
