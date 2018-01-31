
import ../src/lilt/private/parse
import ../src/lilt/inner_ast
import ../src/lilt/private/outer_ast
import ../src/lilt/private/interpret
import ../src/lilt/private/misc

import tables
import strutils
import sequtils

proc test(testName: string, code: string, ruleName: string, input: string, expected: inner_ast.Node) =
    # Test must expect a node, not a list or code.
    echo "Running test '$1'" % testName
    let ast = parseProgram(code).Program

    # TODO: This 3-liner REALLY needs to go in some proc.
    # In fact, the entire interpreter API needs to be cleaned up
    for lamb in ast.descendants.filterOf(Lambda):
        if lamb.parent of Definition:
            lamb.returnNodeKind = lamb.parent.Definition.id

    let ctx = astToContext(ast)
    let rule = ctx[ruleName]
    let res = rule(0, input, initLambdaState(ast.
        descendants
        .filterOf(Definition)
        .findIt(it.id == ruleName)
        .body
        .returnType.toLiltType))

    var resNode: inner_ast.Node
    case res.kind:
    of rrtNode:
        resNode = res.node
    else:
        echo res.kind
        assert false

    if resNode != expected:
        echo "Failed"
        echo "Expected:\n$1\n\nBut got:\n$2" % [$$expected, $$resNode]
        assert false
    echo "Passed"

test(
    "Interpreter test 1",
    """
    sentenceNode: sentence=sentence
    sentence: &word *[", " &word]
    word: val=*<abcdefghijklmnopqrstuvwxyz>
    """,
    "sentenceNode",
    "several, words, in, a, sentence",
    ~~ {
        "kind": "sentenceNode",
        "sentence": [
            {
                "kind": "word",
                "val": "several"
            },
            {
                "kind": "word",
                "val": "words"
            },
            {
                "kind": "word",
                "val": "in"
            },
            {
                "kind": "word",
                "val": "a"
            },
            {
                "kind": "word",
                "val": "sentence"
            }
        ]
    }
)

test(
    "Guard test 1",
    """
    alpha: <abcdefghijklmnopqrstuvwxyz>
    consonant: !<aeiou> $alpha
    consoWord: letters=*consonant
    """,
    "consoWord",
    "bhjdsjkeaklj",
    ~~ {
        "kind": "consoWord",
        "letters": "bhjdsjk"
    }
)

test(
    "String extension 1",
    """
    vowel: <aeiou>
    vowels: *$vowel
    nVowels: val=vowels
    """,
    "nVowels",
    "aeeoouuiaobbbbboisoso",
    ~~ {
        "kind": "nVowels",
        "val": "aeeoouuiao"
    }
)

test(
    "Ex: Function definition",
    """
    tIdentif: +<abcdefghijklmnopqrstuvwxyz>
    nArg: id=tIdentif
    lArgs: ?&nArg *[", " &nArg]
    nFuncdef: "function " id=tIdentif "(" args=lArgs ");"
    """,
    "nFuncdef",
    "function multiply(argone, argtwo, argthree);",
    ~~ {
        "kind": "nFuncdef",
        "id": "multiply",
        "args": [
            {
                "kind": "nArg",
                "id": "argone"
            },
            {
                "kind": "nArg",
                "id": "argtwo"
            },
            {
                "kind": "nArg",
                "id": "argthree"
            }
        ]
    }
)

test(
    "Choice test 1",
    """
    digit: <1234567890>
    letter: <abcdefghijklmnopqrstuvwxyz>
    alphanumeric: digit | letter
    anstring: *alphanumeric
    annode: val=anstring
    """,
    "annode",
    "qwnjgib2723t99 12h8t9",
    ~~ {
        "kind": "annode",
        "val": "qwnjgib2723t99"
    }
)

#[
This test exists to ensure that choice rules
do not give their returned nodes a `kind` that
matches their name.
Instead, the node should be transparently returned
from the matching rule contained in the choice.
]#
test(
    "Choice test 2",
    """
    nBanana: val="banana"
    nApple: val="apple"
    nFruit: nBanana | nApple
    """,
    "nFruit",
    "banana",
    ~~ {
        "kind": "nBanana",
        "val": "banana"
    }
)

test(
    "Lambda test 1",
    """
    identifier: *<abcdefghijklmnopqrstuvwxyz>
    arg: id=identifier
    funcDecl: "func " id=identifier "(" args={ &arg *[", " &arg] } ");"
    """,
    "funcDecl",
    "func pow(a, b);",
    ~~ {
        "kind": "funcDecl",
        "id": "pow",
        "args": [
            {
                "kind": "arg",
                "id": "a"
            },
            {
                "kind": "arg",
                "id": "b"
            }
        ]
    }
)
