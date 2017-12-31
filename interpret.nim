
#[
Here we define the Lilt interpreter.
Though in the future Lilt may become a compiled language,
an interpreter works for now. I want to get all the features
planned and implemented before writing a compiler.

The interpreter works by representing different Lilt
constructs as Nim constructs. This process is referred to
as translation.
Lilt code is translated into Nim code, and a full Lilt
program is mapped to a Nim procedure on a file.
]#

import tables
import strutils as su

import ast
import strfix
import parse

#[
Most Lilt constructs are translated into Rules,
which are functions which take code and either
a) return an integer, the amount of code consumed,
or b) fail. (Sound familiar?)

Failing is done by raising a RuleError.
]#
type Rule = proc(head: int, code: string): int
type RuleError = object of Exception

type LiltContext = TableRef[string, Rule]

type WrongTypeError = object of Exception

const doDebug = true
when not doDebug:
    template debugWrap(rule: Rule, node: Node): Rule =
        rule

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

    proc debugWrap(rule: Rule, node: Node): Rule =
        proc wrappedRule(head: int, code: string): int =
            #debugPush("Attempting to match\n$1\nwith:\n$2" % [$node, code[head ..< code.len]])
            debugPush("Attempting to match $1" % $node)
            #discard readLine(stdin)
            try:
                result = rule(head, code)
            except RuleError as e:
                debugPop("Failed: " & e.msg)
                raise e
            debugPop("Success, head now: " & $result)
            return result
        return wrappedRule


method translate(n: Node, context: LiltContext): Rule {.base.} =
    raise newException(WrongTypeError, "Cannot translate base Node type.")

method translate(re: Reference, context: LiltContext): Rule =
    return context[re.id]

method translate(se: Sequence, context: LiltContext): Rule =
    proc rule(phead: int, code: string): int =
        var head = phead
        for node in se.contents:
            head = translate(node, context)(head, code)
        return head
    return debugWrap(rule, se)

method translate(ch: Choice, context: LiltContext): Rule =
    proc rule(phead: int, code: string): int =
        for node in ch.contents:
            try:
                return translate(node, context)(phead, code)
            except RuleError:
                discard
        raise newException(RuleError, "Didn't match any rule.")
    return debugWrap(rule, ch)

method translate(li: Literal, context: LiltContext): Rule =
    proc rule(phead: int, code: string): int =
        var head = phead
        for ci in 0 ..< li.text.len:
            if li.text[ci] == code{head}:
                inc(head)
            else:
                raise newException(
                    RuleError,
                    "Code didn't match literal at char $1; expected '$2' but got '$3'." % [
                        $head, $li.text[ci], $code{head}
                    ]
                )
        return head
    return debugWrap(rule, li)

method translate(s: Set, context: LiltContext): Rule =
    proc rule(phead: int, code: string): int =
        if code{phead} in s.charset:
            return phead + 1
        raise newException(RuleError, "'$1' not in $2." % [$code{phead}, $s])
    return debugWrap(rule, s)

method translate(o: Optional, context: LiltContext): Rule =
    let innerRule = translate(o.inner, context)
    proc rule(phead: int, code: string): int =
        try:
            return innerRule(phead, code)
        except RuleError:
            return phead
    return debugWrap(rule, o)

method translate(op: OnePlus, context: LiltContext): Rule =
    let innerRule = translate(op.inner, context)
    proc rule(phead: int, code: string): int =
        var head = phead
        var count = 0
        while true:
            try:
                head = innerRule(head, code)
                inc(count)
            except RuleError:
                break

        if count == 0:
            raise newException(RuleError, "Expected code to match at least once.")

        return head
    return debugWrap(rule, op)

method translate(g: Guard, context: LiltContext): Rule =
    let innerRule = translate(g.inner, context)
    proc rule(head: int, code: string): int =
        try:
            discard innerRule(head, code):
        except RuleError:
            return head
        raise newException(RuleError, "Code matched inner guard rule.")
    return debugWrap(rule, g)

proc addDefinition(def: Definition, context: LiltContext) =
    ## Add a definition to a context
    context[def.id] = translate(def.body, context)

proc merge[K, V](t1, t2: TableRef[K, V]) =
    for key in t2.keys:
        t1[key] = t2[key]

# Builtins

var builtins: LiltContext = newTable[string, Rule]()

builtins["anything"] = proc(head: int, code: string): int =
    return head + 1
builtins["whitespace"] = proc(head: int, code: string): int =
    if code{head} in su.Whitespace:
        return head + 1
    raise newException(RuleError, "'$1' is not whitespace." % $code{head})

builtins["lower"] = translate(newSet("abcdefghijklmnopqrstuvwxyz"), builtins)
builtins["upper"] = translate(newSet("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), builtins)
builtins["alpha"] = translate(newChoice(@[
    Node(newReference("lower")),
    Node(newReference("upper")),
]), builtins)

builtins["digit"] = translate(newSet("0123456789"), builtins)
builtins["alphanum"] = translate(newChoice(@[
    Node(newReference("alpha")),
    Node(newReference("digit")),
]), builtins)

builtins["_"] = translate(newOptional(newOnePlus(newReference("whitespace"))), builtins)

method translate(prog: Program): LiltContext {.base.} =
    ## Translates a program to a table of definitions
    var context: LiltContext = newTable[string, Rule]()
    context.merge(builtins)
    for definition in prog.definitions:
        addDefinition(cast[Definition](definition), context)
    return context

#~# Parsing API #~#

proc readProgram(code: string): Node =
    ## Different semantics to parseProgram
    ## Parses a program in full as would be wanted in a simple API
    var (head, node) = parseProgram(0, code)
    if head != code.len:
        raise newException(ParsingError, "Unexpected code at end.")
    return node

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

    const json = """
    [
        {
            "id": "0001",
            "type": "donut",
            "name": "Cake",
            "ppu": 0.55
        },
        {
            "id": "0002",
            "type": "donut",
            "name": "Raised",
            "ppu": 0.55
        }
    ]
    """

    let programAst: Node = readProgram(code)
    let res = translate(cast[Program](programAst))
    echo res["main"](0, json)
