
import strutils as su
import tables

import macros

import ast
import strfix

#~# Parsers #~#

#[
Parsers are functions which operate on raw code;
tokenization is not used as a part of the parsing process.

Parsers accept some string `code`, as well as
a int `head`.
They should start the parsing process at position `head`
in `code`, and never look behind `head`.

They should return the position of `head` after parsing,
as well as the synthesized AST Node.

For instance, a theoretical `parseNumber` applied Like
`parseNumer(0, "14 +")` may return (2, <ast node>)

Paresers should not, under any circumstance, modify
the `code` variable.
]#
type ParserValue = tuple[head: int, node: ast.Node]
type Parser = proc(head: int, code: string): ParserValue

proc `$`(pv: ParserValue): string =
    "($1, $2)" % [$pv.head, $pv.node]

#[
If the given code does not match a parser's specifications,
it may raise a ParsingError.

For instance, `parseNumber(0, "not a number")` may fail.

Failing is different from returning `head` unchanged,
which is succeeding.
]#
type ParsingError* = object of Exception

#~# Consumers #~#

#[
Consumers are like parsers, but do not generate AST Nodes.
They are usful parser helper functions.
They return a variety of things and do not follow any
specific interface.
]#

# NOTE: `phead` stands for `parameter head`
# and is pronounced like `feed` or `fed`

proc consumeWhitespace(phead: int, code: string): int =
    ## Consume 0 or more whitespace characters.
    ## Cannot fail
    var head = phead
    while code{head} in su.Whitespace:
        inc(head)
    return head

proc consumeDotspace(phead: int, code: string): int =
    ## Consume all non-'\l' whitespace
    ## Cannot fail
    var head = phead
    while code{head} != '\l' and code{head} in su.Whitespace:
        inc(head)
    return head

proc consumeString(phead: int, expect: string, code: string): int =
    ## Consume a static string
    ## Failes if code doesn't start with string
    var head = phead
    var actual = code[head ..< head + expect.len]
    if actual == expect:
        return head + expect.len
    raise newException(ParsingError, "Expected string '$1', got '$2'." % [expect, actual])

const
    escapeChar = '\\'
    universalStaticEscapes = {
        "\\": "\\",
        "n": "\r\l",
        "t": "\t",
        "r": "\r",
        "c": "\c",
        "l": "\l",
        "a": "\a",
        "b": "\b",
        "e": "\e",
    }.toTable

proc handleEscapeSequence(phead: int, code: string): (int, string) =
    ## Consumes an escape sequence, including the '\';
    ## Returns the mapped value as well as the new head
    var head = phead
    head = head.consumeString($escapeChar, code)

    if universalStaticEscapes.hasKey($code{head}):
        return (head + 1, universalStaticEscapes[$code{head}])

    # TODO parse decimal / hex escape codes
    raise newException(ParsingError, "Unkown escape char '$1'." % $code{head})

proc consumeFromSet(phead: int, charset: set[char], specialEscapes: Table[char, string], code: string): (int, string) =
    ## Consume while chars are in charset
    ## Handles default escape codes, as well as any special escapes passed in
    ## Return all consumed code as well as new head
    ## Only fails on an invalid escape sequence
    var head = phead
    var consumed = ""
    while true:
        let c = code{head}
        if c == escapeChar:
            var processed: string  # Processed escape sequence
            if specialEscapes.hasKey(c):
                inc(head)
                processed = specialEscapes[c]
            else:  # If not a special escape, defer to global escapes
                (head, processed) = head.handleEscapeSequence(code)
                consumed &= processed
        elif c in charset:
            consumed &= c
            inc(head)
        else:
            break
    return (head, consumed)

const
    identifierChars = Letters + Digits + {'_'}
proc extractIdentifier(phead: int, code: string): (int, string) =
    ## Parses out an identifier
    ## Fails on 0-length
    var head = phead
    var ide = ""

    while code{head} in identifierChars:
        ide &= code{head}
        inc(head)

    if ide == "":
        raise newException(ParsingError, "Invalid identifier character '$1'." % $code{head})
    return (head, ide)

#~# Debug stuff #~#

const doDebug = false

when not doDebug:
    template debugParserDecorator(parser: untyped): typed =
        parser

else:
    var debugDepth = 0

    proc debugEcho(msg: string) =
        echo ".    ".repeat(debugDepth) & msg

    proc debugPush(msg: string) =
        debugEcho(msg)
        inc(debugDepth)

    proc debugPop(msg: string) =
        dec(debugDepth)
        debugEcho(msg)

    macro debugParserDecorator(parser: untyped): typed =
        ## A macro for debugging which spits out
        ## useful info into the console.
        ## Should be used as a pragma on `Parser`s ONLY.
        let
            procName = NimNode(parser).name
            startMsg = "PARSE: $1" % $procName
            failMsg = "FAIL: $1; " % $procName
            succMsg = "SUCC: $1; " % $procName

        result = quote do:
            proc `procName`(phead: int, code: string): ParserValue =
                `parser`  # Insert given function under name `procName`
                debugPush(`startMsg`)
                var res: ParserValue
                try:
                    res = `procName`(phead, code)  # Call `parser`
                except ParsingError as e:
                    debugPop(`failMsg` & e.msg)
                    raise e
                debugPop(`succMsg` & $res)
                return res

#~# Actual parser definitions #~#

proc parseExpression*(phead: int, code: string): ParserValue
proc parseBody*(phead: int, code: string): ParserValue

proc parseReference*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    var ide: string
    (head, ide) = head.extractIdentifier(code)

    return (head, ast.newReference(ide))

const shortLiteralEscapes = {'\'': "'"}.toTable
const shortLiteralCharset = AllChars - Whitespace - {'\''}
proc parseShortLiteral*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    head = head.consumeString("'", code)
    var literal: string
    (head, literal) = head.consumeFromSet(shortLiteralCharset, shortLiteralEscapes, code)

    return (head, ast.newLiteral(literal))

const longLiteralEscapes = {'"': "\""}.toTable
const longLiteralCharset = AllChars - {'"'}
proc parseLongLiteral*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    head = head.consumeString("\"", code)
    var literal: string
    (head, literal) = head.consumeFromSet(longLiteralCharset, longLiteralEscapes, code)

    return (head, ast.newLiteral(literal))

const setEscapes = {'<': "<", '>': ">"}.toTable
const setCharset = AllChars - {'<', '>'}
proc parseSet*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    head = head.consumeString("<", code)
    var charset: string
    (head, charset) = head.consumeFromSet(setCharset, setEscapes, code)
    head = head.consumeString(">", code)

    return (head, ast.newSet(charset))

proc parseOptional*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    head = head.consumeString("?", code)
    var innerNode: ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, ast.newOptional(innerNode))

proc parseOnePlus*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    head = head.consumeString("+", code)
    var innerNode: ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, ast.newOnePlus(innerNode))

proc parseZeroPlus*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    # We define `*expr` to actually just be a macro for `?+expr`.
    var head = phead

    head = head.consumeString("*", code)
    var innerNode: ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, ast.newOptional(ast.newOnePlus(innerNode)))

proc parseGuard*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    head = head.consumeString("!", code)
    var innerNode: ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, ast.newGuard(innerNode))

proc parseBrackets*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    # Like groups in other languages
    var head = phead

    head = head.consumeString("[", code)
    head = head.consumeWhitespace(code)

    var innerNode: ast.Node
    (head, innerNode) = head.parseBody(code)

    head = head.consumeWhitespace(code)
    head = head.consumeString("]", code)

    return (head, innerNode)

proc parseExpression*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    const options: seq[Parser] = @[
        Parser(parseReference),
        Parser(parseShortLiteral),
        Parser(parseLongLiteral),
        Parser(parseSet),
        Parser(parseOptional),
        Parser(parseOnePlus),
        Parser(parseZeroPlus),
        Parser(parseGuard),
        Parser(parseBrackets)
    ]

    for option in options:
        try:
            return option(phead, code)
        except ParsingError: discard

    raise newException(ParsingError, "Matched no option.")

proc parseChoice*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var
        head = phead
        innerNodes: seq[ast.Node] = @[]
        isFirst = true
        passedAtLeastOnePipe = false

    while head < code.len:
        if not isFirst:
            head = head.consumeWhitespace(code)  # Allow space before pipe
            if code{head} != '|':
                if passedAtLeastOnePipe:
                    break  # End of or expression; return
                else:
                    raise newException(ParsingError, "Expected at least one pipe.")
            passedAtLeastOnePipe = true
            head.inc  # Consume pipe
            head = head.consumeWhitespace(code)  # Allow space after pipe
        else:
            isFirst = false

        var innerNode: ast.Node
        (head, innerNode) = head.parseExpression(code)
        innerNodes.add(innerNode)

    return (head, ast.newChoice(innerNodes))

proc parseSequence*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead
    var innerNodes: seq[ast.Node] = @[]

    var innerNode: ast.Node
    while head < code.len:
        try:
            (head, innerNode) = head.parseExpression(code)
        except ParsingError:
            break

        # Allow dotspace between simple expressions
        # Don't allow newlines because then identifiers
        # at the beginning of definitions may be parsed as
        # references instead
        # TODO: Will consume code after sequence
        head = head.consumeDotspace(code)
        innerNodes.add(innerNode)

    if innerNodes.len < 1:
        raise newException(ParsingError, "Expected at least one simple expression.")

    return (head, ast.newSequence(innerNodes))

proc parseBody*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    const options = @[
        parseChoice,
        parseSequence,
    ]

    for option in options:
        try:
            return option(phead, code)
        except ParsingError: discard

    raise newException(ParsingError, "Matched no options.")

proc parseDefinition*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    var ide: string
    (head, ide) = head.extractIdentifier(code)

    head = head.consumeString(":", code)
    head = head.consumeWhitespace(code)  # Allow whitespace between ':' and body

    var body: ast.Node
    (head, body) = head.parseBody(code)

    return (head, ast.newDefinition(ide, body))

proc parseProgram*(phead: int, code: string): ParserValue {.debugParserDecorator.} =
    var head = phead

    var definitions: seq[ast.Node] = @[]

    head = head.consumeWhitespace(code)
    while head < code.len:
        var definition: ast.Node
        (head, definition) = head.parseDefinition(code)
        definitions.add(definition)
        head = head.consumeWhitespace(code)

    return (head, ast.newProgram(definitions))

when isMainModule:
    const code = """

    object: '{ _ *members _ '}
    members: string _ ': _ value ?[_ ', _ members]

    array: '[ _ *values _ ']
    values: value ?[_ ', _ values]

    value: string | number | object | array | 'true | 'false | 'null

    string: '" *strChar '"
    strChar: [!<"\\> anything]
        | ['\\ <"\\/bfnrt>]
        | ['\\u hexDigit hexDigit hexDigit hexDigit]
    hexDigit: digit | <abcdefABCDEF>

    nonZero: !'0 digit
    number: ?'- ['0 | [nonZero *digit]] ?['. +digit] ?[['e | 'E ] ?['+ | '- ] +digit]

    main: _ array _

    """

    var res = parseProgram(0, code).node
    echo $res
    echo $$res
    echo res.toLilt
