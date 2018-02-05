
include hparser

const spec = slurp("ParserSpec0015.lilt")
test(
    spec,
    newProgram(@[
          "__" := ~[ ! @"newline", @"_" ]
        , "identifier" := ~[ @"alpha", * @"alphanum" ]
        , "typedArg" %= ~[ "name" .= @"identifier", @"__", ^":", @"__", "type" .= @"identifier" ]
        , "lambda" %= ~[ "args" .= % + ~[ & @"typedArg", @"__" ], ^":", "body" .= @"expression" ]
        , "expression" := |[ @"lambda", @"literal" ]
        , "literal" := |[ @"charLiteral", @"strLiteral", @"numberLiteral" ]
        , "charLiteral" %= ~[ ^"'", "text" .= @"any" ]
        , "strLiteral" %= ~[ ^"\"", "text" .= * @"any", ^"\"" ]
        , "numberLiteral" %= ( "text" .= % * ~[ $: @"digit", ? ^"_" ] )
    ])
)
