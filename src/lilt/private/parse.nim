
import strutils
import tables
import macros
import options

import outer_ast
import strfix
import inner_ast
import quick
import interpret
import misc
import sequtils
import types

let liltParserAst = outer_ast.newProgram(@[ "" := ^""  # This rule is only added to allow for a `,` in front of EVERY line after
    , "lineComment"   := ~[ ^"/", $: ^"", * ~[ ! @"newline", @"any" ] ]  # $: ^"" included so always returns ""
    , "blockComment"  := ~[ ^"((", $: ^"", * ~[ ! ^"))", @"any" ], ^"))" ]
    , "comment"       := |[ @"lineComment", @"blockComment" ]

    # `d` as in "dead space"
    , "d" := * |[ @"whitespace", @"comment" ]

    , "identifier" :=  ( + @"alphanum" )

    , "program"    := ~[ "definitions" .= % * ~[ @"d", & @"definition" ], @"d" ]
    , "definition" := ~[ "id" .= @"identifier" , @"d", ^":", @"_", "body" .= @"body" ]

    , "body" := |[
          @"sequence"
        , @"choice"
        , @"expression"
    ]

    #                                                         TODO dotspace
    , "sequence" := ~[ "contents" .= % ~[ & @"expression", + ~[ * |[ <>" \t", @"comment" ], & @"expression" ] ] ]
    , "choice"   := ~[ "contents" .= % ~[ & @"expression", + ~[ @"d", ^"|", @"d", & @"expression" ] ] ]

    , "expression" := |[
          @"property"  # Must go before reference because both begin with an identifier
        , @"reference"
        , @"literal"
        , @"set"
        , @"optional"
        , @"oneplus"
        , @"zeroplus"
        , @"guard"
        , @"adjoinment"
        , @"extension"
        , @"brackets"
        , @"lambda"
    ]

    , "escapeChar" := ^"\\"
    # Implements the following escapes: \trclabe
    # In parsed code, they will appear with the backslash;
    # the escapes need to be converted in Nim.
    , "maybeEscapedChar" := |[
          ~[ ! @"escapeChar", @"any" ]  # Any non-backslash OR
        , ~[ @"escapeChar", <>"\\trclabe" ]  # A blackslash followed by one of: \trclabe
    ]

    , "reference"   :=  ( "id" .= @"identifier" )

    , "literalChar" := |[
          ~[ @"escapeChar", ^"\"" ]  # \" OR
        , ~[ ! ^"\"", @"maybeEscapedChar" ]  # a non-" normally-behaving char
    ]
    , "literal"     := ~[ ^"\"", "text" .= * @"literalChar", ^"\"" ]

    , "setChar"     := |[
          ~[ @"escapeChar", ^">" ]  # \> OR
        , ~[ ! ^">", @"maybeEscapedChar" ]  # a non-> normally-behaving char
    ]
    , "set"         := ~[ ^"<", "charset" .= * @"setChar", ^">" ]

    , "optional"    := ~[ ^"?", "inner" .= @"expression" ]
    , "oneplus"     := ~[ ^"+", "inner" .= @"expression" ]
    , "zeroplus"    := ~[ ^"*", "inner" .= @"expression" ]
    , "guard"       := ~[ ^"!", "inner" .= @"expression" ]

    , "adjoinment"  := ~[ ^"$", "inner" .= @"expression" ]
    , "property"    := ~[ "propName" .= @"identifier", ^"=", "inner" .= @"expression" ]
    , "extension"   := ~[ ^"&", "inner" .= @"expression" ]

    , "brackets"    := ~[ ^"[", @"d", "body" .= @"body", @"d", ^"]" ]
    , "lambda"      := ~[ ^"{", @"d", "body" .= @"body", @"d", ^"}" ]
])

types.preprocess(liltParserAst)
let parsers: Table[string, Parser] = programToContext(liltParserAst)
let programParser = parsers["program"]

proc toOuterAst(node: inner_ast.Node): ONode

proc parseProgram*(code: string): Program =
    return  programParser(code).node.toOuterAst.Program

proc unescape(s: string): string =
    # Maps escape codes to values
    return s.multiReplace({
        "\\\"": "\"",
        "\\>": ">",
        "\\t": "\t",
        "\\r": "\r",
        "\\c": "\c",
        "\\l": "\l",
        "\\a": "\a",
        "\\b": "\b",
        "\\e": "\e",
        "\\\\": "\\",
    })

proc toOuterAst(node: inner_ast.Node): ONode =
    case node.kind:
    of "program":
        return newProgram(node["definitions"].list.mapIt(it.toOuterAst))
    of "definition":
        return newDefinition(node["id"].text, newLambda(node["body"].node.toOuterAst))
    of "sequence":
        return newSequence(node["contents"].list.mapIt(it.toOuterAst))
    of "choice":
        return newChoice(node["contents"].list.mapIt(it.toOuterAst))
    of "reference":
        return newReference(node["id"].text)
    of "literal":
        return newLiteral(node["text"].text.unescape)
    of "set":
        return newSet(node["charset"].text.unescape)
    of "optional":
        return newOptional(node["inner"].node.toOuterAst)
    of "oneplus":
        return newOnePlus(node["inner"].node.toOuterAst)
    of "zeroplus":
        return newOptional(newOnePlus(node["inner"].node.toOuterAst))
    of "guard":
        return newGuard(node["inner"].node.toOuterAst)
    of "adjoinment":
        return newAdjoinment(node["inner"].node.toOuterAst)
    of "property":
        return newProperty(node["propName"].text, node["inner"].node.toOuterAst)
    of "extension":
        return newExtension(node["inner"].node.toOuterAst)
    of "brackets":
        return node["body"].node.toOuterAst
    of "lambda":
        return newLambda(node["body"].node.toOuterAst)
    else:
        assert false
