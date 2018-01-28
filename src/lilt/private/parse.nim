
import strutils
import tables

import macros

import outer_ast
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
type ParserValue = tuple[head: int, node: outer_ast.Node]
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

# NOTE: `head` stands for `parameter head`
# and is pronounced like `feed` or `fed`

proc consumeComment(head: int, code: string): int

proc consumeDeadspace(head: int, code: string): int =
    ## Consumes whitespace and comments
    var head = head
    while true:
        if code{head} in strutils.Whitespace:
            inc(head)
        elif code{head} == '/':
            head = head.consumeComment(code)
        else:
            return head

const dotSpace = strutils.Whitespace - strutils.NewLines
proc consumeDotdead(head: int, code: string): int =
    ## Consume non-newline whitespace
    ## as well as comments
    var head = head
    while true:
        if code{head} in dotSpace:
            inc(head)
        elif code{head} == '/':
            head = head.consumeComment(code)
        else:
            return head

proc consumeString(head: int, expect: string, code: string): int =
    ## Consume a static string
    ## Failes if code doesn't start with string
    var head = head
    var actual = code[head ..< head + expect.len]
    if actual == expect:
        return head + expect.len
    raise newException(ParsingError, "Expected string '$1', got '$2'." % [expect, actual])

proc consumeBlockComment(head: int, code: string): int =
    var head = head
    head = head.consumeString("/(", code)
    # We allow for nested comments; keep track of depth
    var depth = 1

    while true:
        let c = code{head}

        if c == '\0':
            raise newException(ParsingError, "End of file reached before comment finished.")
        elif c == '/':
            # Beginning of block comment
            if code{head + 1} != '(':
                raise newException(ParsingError, "Expected '(' after '/'.")

            head += 2
            inc(depth)
        elif c == ')':
            depth -= 1
            head += 1
        else:
            head += 1

        if depth == 0:
            return head

proc consumeLineComment(head: int, code: string): int =
    var head = head
    head = head.consumeString("/", code)

    while code{head} notin strutils.NewLines and code{head} != '\0':
        inc(head)

    if code{head} == '\0':
        return head

    # consume all \c and all \l
    while code{head} in strutils.NewLines:
        inc(head)
    return head

proc consumeComment(head: int, code: string): int =
    if code{head} == '/':
        if code{head + 1} == '(':
            return head.consumeBlockComment(code)
        return head.consumeLineComment(code)
    raise newException(ParsingError, "Comments must begin with '/'.")

const
    escapeMarker = '\\'
    universalStaticEscapes = {
        '\\': "\\",
        't': "\t",
        'r': "\r",
        'c': "\c",
        'l': "\l",
        'a': "\a",
        'b': "\b",
        'e': "\e",
    }.toTable

proc handleEscapeSequence(head: int, code: string): (int, string) =
    ## Consumes an escape sequence, including the '\';
    ## Returns the mapped value as well as the new head
    var head = head

    head = head.consumeString($escapeMarker, code)

    if universalStaticEscapes.hasKey(code{head}):
        return (head + 1, universalStaticEscapes[code{head}])

    raise newException(ParsingError, "Unkown escape char '$1'." % $code{head})

proc consumeFromSet(head: int, charset: set[char], specialEscapes: Table[char, string], code: string): (int, string) =
    ## Consume while chars are in charset
    ## Handles default escape codes, as well as any special escapes passed in
    ## Return all consumed code as well as new head
    ## Only fails on an invalid escape sequence
    var head = head
    var consumed = ""
    while true:
        let c = code{head}
        if c == escapeMarker:
            let escapeChar = code{head + 1}
            var processed: string  # Processed escape sequence
            if specialEscapes.hasKey(escapeChar):
                processed = specialEscapes[escapeChar]
                head += 2
            else:  # If not a special escape, defer to global escapes
                (head, processed) = handleEscapeSequence(head, code)
            consumed &= processed
        elif c in charset:
            consumed &= c
            inc(head)
        else:
            break
    return (head, consumed)

const identifierChars = Letters + Digits + {'_'}
proc extractIdentifier(head: int, code: string): (int, string) =
    ## Parses out an identifier
    ## Fails on 0-length
    var head = head
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
    template debug(parser: untyped): typed =
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

    macro debug(parser: untyped): typed =
        ## A macro for debugging which spits out
        ## useful info into the console.
        ## Should be used as a pragma on `Parser`s ONLY.
        let
            procName = NimNode(parser).name
            procNameStr = $procName

        result = quote do:
            proc `procName`(head: int, code: string): ParserValue =
                `parser`  # Insert given function under name `procName`
                debugPush("PARSE: $1" % `procNameStr`)
                var res: ParserValue
                try:
                    res = `procName`(head, code)  # Call `parser`
                except ParsingError as e:
                    debugPop("FAIL: $1; ERR: $2" % [`procNameStr`, e.msg])
                    raise e

                debugPop("SUCC: $1" % $res)
                return res

#~# Actual parser definitions #~#

proc parseExpression(head: int, code: string): ParserValue
proc parseBody(head: int, code: string): ParserValue

proc parseReference(head: int, code: string): ParserValue {.debug.} =
    var head = head

    var ide: string
    (head, ide) = head.extractIdentifier(code)

    return (head, outer_ast.newReference(ide))

const literalEscapes = {'"': "\""}.toTable
const literalCharset = AllChars - {'"'}
proc parseLiteral(head: int, code: string): ParserValue {.debug.} =
    var head = head

    head = head.consumeString("\"", code)
    var literal: string
    (head, literal) = head.consumeFromSet(literalCharset, literalEscapes, code)
    head = head.consumeString("\"", code)

    return (head, outer_ast.newLiteral(literal))

const setEscapes = {'<': "<", '>': ">"}.toTable
const setCharset = AllChars - {'<', '>'}
proc parseSet(head: int, code: string): ParserValue {.debug.} =
    var head = head

    head = head.consumeString("<", code)
    var charset: string
    (head, charset) = head.consumeFromSet(setCharset, setEscapes, code)
    head = head.consumeString(">", code)

    return (head, outer_ast.newSet(charset))

proc parseOptional(head: int, code: string): ParserValue {.debug.} =
    var head = head

    head = head.consumeString("?", code)
    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, outer_ast.newOptional(innerNode))

proc parseOnePlus(head: int, code: string): ParserValue {.debug.} =
    var head = head

    head = head.consumeString("+", code)
    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, outer_ast.newOnePlus(innerNode))

proc parseZeroPlus(head: int, code: string): ParserValue {.debug.} =
    # We define `*expr` to actually just be a macro for `?+expr`.
    var head = head

    head = head.consumeString("*", code)
    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, outer_ast.newOptional(outer_ast.newOnePlus(innerNode)))

proc parseGuard(head: int, code: string): ParserValue {.debug.} =
    var head = head

    head = head.consumeString("!", code)
    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, outer_ast.newGuard(innerNode))

proc parseBrackets(head: int, code: string): ParserValue {.debug.} =
    # Like groups in other languages
    var head = head

    head = head.consumeString("[", code)
    head = head.consumeDeadspace(code)

    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseBody(code)

    head = head.consumeDeadspace(code)
    head = head.consumeString("]", code)

    return (head, innerNode)

proc parseExtension(head: int, code: string): ParserValue {.debug.} =
    var head = head
    
    head = head.consumeString("&", code)
    
    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, outer_ast.newExtension(innerNode))

proc parseAdjoinment(head: int, code: string): ParserValue {.debug.} =
    var head = head

    head = head.consumeString("$", code)

    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, outer_ast.newAdjoinment(innerNode))

proc parseProperty(head: int, code: string): ParserValue {.debug.} =
    var head = head

    var propertyName: string
    (head, propertyName) = head.extractIdentifier(code)

    head = head.consumeString("=", code)

    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseExpression(code)

    return (head, outer_ast.newProperty(propertyName, innerNode))

proc parseLambda(head: int, code: string): ParserValue {.debug.} =
    var head = head

    head = head.consumeString("{", code)
    head = head.consumeDeadspace(code)

    var innerNode: outer_ast.Node
    (head, innerNode) = head.parseBody(code)

    head = head.consumeDeadspace(code)
    head = head.consumeString("}", code)

    return (head, outer_ast.newLambda(innerNode))

proc parseExpression(head: int, code: string): ParserValue {.debug.} =
    const options = [
        parseProperty, # Must go before parseReference because starts with an identifier
        parseReference,
        parseExtension,
        parseAdjoinment,
        parseLiteral,
        parseSet,
        parseOptional,
        parseOnePlus,
        parseZeroPlus,
        parseGuard,
        parseBrackets,
        parseLambda
    ]

    for option in options:
        try:
            return option(head, code)
        except ParsingError: discard

    raise newException(ParsingError, "Matched no option.")

proc parseChoice(head: int, code: string): ParserValue {.debug.} =
    var
        head = head
        innerNodes: seq[outer_ast.Node] = @[]
        isFirst = true
        passedAtLeastOnePipe = false

    while true:
        if not isFirst:
            head = head.consumeDeadspace(code)  # Allow space before pipe
            if code{head} != '|':
                if passedAtLeastOnePipe:
                    break  # End of or expression; return
                else:
                    raise newException(ParsingError, "Expected at least one pipe.")
            passedAtLeastOnePipe = true
            head.inc  # Consume pipe
            head = head.consumeDeadspace(code)  # Allow space after pipe
        else:
            isFirst = false

        var innerNode: outer_ast.Node
        (head, innerNode) = head.parseExpression(code)
        innerNodes.add(innerNode)

    return (head, outer_ast.newChoice(innerNodes))

proc parseSequence(head: int, code: string): ParserValue {.debug.} =
    var head = head
    var innerNodes: seq[outer_ast.Node] = @[]
    var isFirstItem = true

    var innerNode: outer_ast.Node
    while head < code.len:

        let headBeforeConsumingSpace = head
        if not isFirstItem:
            # Consume space between items
            head = head.consumeDotdead(code)

        try:
            (head, innerNode) = head.parseExpression(code)
        except ParsingError:
            # Only consume space between items, not after last item
            head = headBeforeConsumingSpace
            break

        isFirstItem = false

        # Allow dotspace between simple expressions
        # Don't allow newlines because then identifiers
        # at the beginning of definitions may be parsed as
        # references instead
        innerNodes.add(innerNode)

    if innerNodes.len < 2:
        raise newException(ParsingError, "Expected at least two simple expressions.")

    return (head, outer_ast.newSequence(innerNodes))

proc parseBody(head: int, code: string): ParserValue {.debug.} =
    const options = [
        parseChoice,
        parseSequence,
        parseExpression,
    ]

    for option in options:
        try:
            return option(head, code)
        except ParsingError: discard

    raise newException(ParsingError, "Matched no options.")

proc parseDefinition(head: int, code: string): ParserValue {.debug.} =
    var head = head

    var ide: string
    (head, ide) = head.extractIdentifier(code)

    head = head.consumeString(":", code)
    head = head.consumeDeadspace(code)  # Allow whitespace between ':' and body

    var body: outer_ast.Node
    (head, body) = head.parseBody(code)

    let lamb = newLambda(body, ide)
    return (head, outer_ast.newDefinition(ide, lamb))

proc parseProgram(head: int, code: string): ParserValue {.debug.} =
    var head = head

    var definitions: seq[outer_ast.Node] = @[]

    head = head.consumeDeadspace(code)
    while head < code.len:
        var definition: outer_ast.Node
        (head, definition) = head.parseDefinition(code)
        definitions.add(definition)
        head = head.consumeDeadspace(code)

    return (head, outer_ast.newProgram(definitions))

#~# Exposed API #~#

proc parseProgram*(code: string): outer_ast.Node =
    var (head, node) = parseProgram(0, code)
    if head < code.len:
        raise newException(ParsingError, "Extranious code at loc $1" % $head)
    return node

import macros
macro expose(procName: untyped): typed =
    return quote do:
        proc `procName`*(code: string): outer_ast.Node =
            return `procName`(0, code).node

expose(parseDefinition)
expose(parseSequence)
expose(parseChoice)
expose(parseExpression)
expose(parseProperty)
expose(parseExtension)
expose(parseBrackets)
expose(parseGuard)
expose(parseZeroPlus)
expose(parseOnePlus)
expose(parseOptional)
expose(parseSet)
expose(parseLiteral)
expose(parseReference)
expose(parseAdjoinment)
expose(parseLambda)
