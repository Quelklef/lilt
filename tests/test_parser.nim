
import ../src/lilt/private/outer_ast
import ../src/lilt/private/parse
import ../src/lilt/private/quick

import strutils

template test(testName: string, code: string, expected: Node) =
    let parsed: Node = parseProgram(code)
    echo "Running test '$1'" % testName
    if not equiv(parsed, expected):
        echo "Failed; expected ast:"
        echo $$expected
        echo "but got:"
        echo $$parsed
        echo "Failed '$1'" % testName
        assert false
    echo "Passed"


test(
    "Parsing Super Duper Easy",
    "simple: \"simple\"",
    newProgram(@[
        "simple" := ^"simple"
    ])
)

test(
    "Parsing 1",
    """
    char: *<abcdefg>
    string: +char
    """,
    newProgram(@[
        "char" := * <>"abcdefg"
        , "string" := + @"char"
    ])
)

test(
    "Sequences 1",
    "ex: \"a\" \"b\"",
    newProgram(@[
        "ex" := ~[ ^"a" , ^"b" ]
    ])
)

test(
    "This bug is a damned pain",
    "ex: &e *[\"b\" &e]",
    newProgram(@[
        "ex" := ~[ & @"e", * ~[ ^"b", & @"e" ] ]
    ])
)

test(
    "Extensions 1",
    "args: &arg *[\" \" &arg]",
    newProgram(@[
        "args" := ~[ & @"arg", * ~[ ^" ", & @"arg" ] ]
    ])
)

test(
    "Adjoinment",
    """
    handleString: "'" $*char "'"
    """,
    newProgram(@[
        "handleString" := ~[ ^"'", $: * @"char", ^"'" ]
    ])
)

test(
    "Escape quote",
    """ex: "\"" """,
    newProgram(@[
        "ex" := ^"\\\""
    ])
)

test(
    "Escape set",
    """ex: <\>>""",
    newProgram(@[
        "ex" := <>"\\>"
    ])
)

test(
    "Escapes most",
    """ex: "\t\r\c\l\a\b\e\\" """,
    newProgram(@[
        "ex" := ^"\\t\\r\\c\\l\\a\\b\\e\\\\"
    ])
)

#[ test(
    "Comments 1",
    """
     /( Block comment! )
     / Line comment
    vowel: <aeiou>/This is a comment
    /(/( nest a comment
    Let's add /() some code in the comments:
    code: <code> ))
    """,
    newProgram(@[
        newDefinition(
            "vowel",
            newLambda(newSet("aeiou"))
        ).Node
    ])
) ]#

test(
    "Lambda 1",
    "lambTest: { <a> }",
    newProgram(@[
        "lambTest" := % <>"a"
    ])
)
