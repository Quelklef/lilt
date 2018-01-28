
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
import strutils
import sequtils

import outer_ast
import ../inner_ast
import strfix
import parse
import types
import base
from misc import findIt

#[
Most Lilt constructs are translated into Rules,
which are functions which take code and either
a) return an integer, the amount of code consumed,
or b) fail. (Sound familiar?)

Failing is done by raising a RuleError.
]#

type
    RuleVal* = object of RootObj
        head*: int
        lambdaState*: LambdaState

        case kind*: RuleReturnType:
        of rrtText:
            text*: string
        of rrtNode:
            node*: inner_ast.Node
        of rrtList:
            list*: seq[inner_ast.Node]
        of rrtNone:
            discard

    #[
    Each new reference / run of a definiton's rule makes a new LambdaState.
    This LambdaState is what the statements in the rule modifies.
    ]#
    LambdaState* = object of RootObj
        case kind*: LiltType
        of ltText:
            text*: string
        of ltNode:
            node*: inner_ast.Node
        of ltList:
            list*: seq[inner_ast.Node]

proc toProperty(rv: RuleVal): inner_ast.Property =
    case rv.kind:
    of rrtText:
        return inner_ast.initProperty(rv.text)
    of rrtNode:
        return inner_ast.initProperty(rv.node)
    of rrtList:
        return inner_ast.initProperty(rv.list)
    of rrtNone:
        raise newException(ValueError, "RuleValue but not be of kind rrtNone")

proc hls(rv: RuleVal): (int, LambdaState) =
    # No semantic meaning, exists only to make code terser
    return (rv.head, rv.lambdaState)

proc `$`(s: seq[inner_ast.Node]): string =
    result = "@["
    var firstItem = true
    for node in s:
        if not firstItem: result &= ", "
        result &= $node
        firstItem = false
    result &= "]"

proc `$`(rv: RuleVal): string =
    case rv.kind:
    of rrtText:
        return "head: $1; text: '$2'" % [$rv.head, rv.text]
    of rrtList:
        return "head: $1; list: $2" % [$rv.head, $rv.list]
    of rrtNode:
        return "head: $1; node: $2" % [$rv.head, $rv.node]
    of rrtNone:
        return "head: $1, kind: $2" % [$rv.head, $rv.kind]

converter toRuleVal(retVal: (int, string, LambdaState)): RuleVal =
    return RuleVal(
        kind: rrtText,
        head: retVal[0],
        text: retVal[1],
        lambdaState: retVal[2],
    )

converter toRuleVal(retVal: (int, seq[inner_ast.Node], LambdaState)): RuleVal =
    return RuleVal(
        kind: rrtList,
        head: retVal[0],
        list: retVal[1],
        lambdaState: retVal[2],
    )

converter toRuleval(retVal: (int, inner_ast.Node, LambdaState)): RuleVal =
    return RuleVal(
        kind: rrtNode,
        head: retVal[0],
        node: retVal[1],
        lambdaState: retVal[2],
    )

converter toRuleVal(retVal: (int, LambdaState)): RuleVal =
    return RuleVal(
        kind: rrtNone,
        head: retVal[0],
        lambdaState: retVal[1],
    )

proc initLambdaState*(kind: LiltType): LambdaState =
    case kind:
    of ltText:
        result = LambdaState(kind: ltText, text: "")
    of ltList:
        result = LambdaState(kind: ltList, list: @[])
    of ltNode:
        # The kind will be added in the top-leve sequence
        result = LambdaState(kind: ltNode, node: inner_ast.initNode(""))
    else:
        assert false

type Rule* = proc(head: int, text: string, lambdaState: LambdaState): RuleVal
type RuleError* = object of Exception

type LiltContext* = TableRef[string, Rule]

const doDebug = false
when not doDebug:
    template debugWrap(rule: Rule, node: outer_ast.Node): Rule =
        rule

else:
    var debugDepth = 0

    proc debugEcho(msg: string) =
        echo ".   ".repeat(debugDepth) & msg

    proc debugPush(msg: string) =
        debugEcho(msg)
        inc(debugDepth)

    proc debugPop(msg: string) =
        dec(debugDepth)
        debugEcho(msg)

    proc debugWrap(rule: Rule, node: outer_ast.Node): Rule =
        proc wrappedRule(head: int, text: string, lambdaState: LambdaState): RuleVal =
            debugPush("Attempting to match $1" % $node)
            try:
                result = rule(head, text, lambdaState)
            except RuleError as e:
                debugPop("Failed: " & e.msg)
                raise e
            assert result.kind == node.returnType
            debugPop("Success, head now: " & $result.head)
            return result
        return wrappedRule


type WrongTypeError = object of Exception

method translate(node: outer_ast.Node, context: LiltContext): Rule {.base.} =
    raise newException(WrongTypeError, "Cannot translate node $1" % $node)

let emptyContext = newTable[string, Rule]()

template toRule[T](s: set[T]): Rule =
    translate(newSet(s), emptyContext)

let builtins = {
    "newline": translate(
        newOptional(newOnePlus(
            newSet("\r\l")
        )),
        emptyContext
    ),
    "whitespace": strutils.Whitespace.toRule,
    "_": translate(
        newOptional(newOnePlus(
            newSet(strutils.Whitespace)
        )),
        emptyContext
    ),
    "any": Rule(proc(head: int, text: string, lambdaState: LambdaState): RuleVal =
        return (head + 1, lambdaState)
    ),
    "lower": {'a' .. 'z'}.toRule,
    "upper": {'A' .. 'Z'}.toRule,
    "alpha": strutils.Letters.toRule,
    "digit": strutils.Digits.toRule,
    "alphanum": toRule(strutils.Letters + strutils.Digits),
}.newTable

method translate(re: Reference, context: LiltContext): Rule =
    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        # Creating new lambda states is handled in the translate(Lambda) code
        if re.id in context:
            return context[re.id](head, text, lambdaState)
        else:
            return builtins[re.id](head, text, lambdaState)

    return debugWrap(rule, re)

method translate(lamb: Lambda, context: LiltContext): Rule =
    let innerRule = translate(lamb.body, context)
    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        # Each lambda call gets its own context, so create one.
        var returnVal = innerRule(head, text, initLambdaState(lamb.returnType.toLiltType))

        # TODO: Should we be checking the type of the body here?
        # Should it be handled earlier?

        if lamb.body of Choice:
            case lamb.returnType:
            of rrtText:
                return (returnVal.head, returnVal.text, lambdaState)
            of rrtNode:
                return (returnVal.head, returnVal.node, lambdaState)
            of rrtList:
                return (returnVal.head, returnVal.list, lambdaState)
            of rrtNone:
                assert false

        else:
            case lamb.returnType:
            of rrtText:
                let hasAdj = lamb.scoped.anyIt(it of Adjoinment)
                if hasAdj:
                    # Text found via mutation of lambdaState
                    return (returnVal.head, returnVal.lambdaState.text, lambdaState)
                else:
                    # Text found via return
                    return (returnVal.head, returnVal.text, lambdaState)
            of rrtNode:
                returnVal.lambdaState.node.kind = lamb.returnNodeKind
                return (returnVal.head, returnVal.lambdaState.node, lambdaState)
            of rrtList:
                return (returnVal.head, returnVal.lambdaState.list, lambdaState)
            of rrtNone:
                assert false

    return debugWrap(rule, lamb)

method translate(se: Sequence, context: LiltContext): Rule =
    var rule: proc(head: int, text: string, lambdaState: LambdaState): RuleVal

    case se.returnType:
    of rrtText:
        rule = proc(head: int, text: string, lambdaState: LambdaState): RuleVal =
            var head = head
            var lambdaState = lambdaState
            
            var returnText = ""

            for node in se.contents:
                let returnVal = translate(node, context)(head, text, lambdaState)
                (head, lambdaState) = returnVal.hls

                case returnVal.kind:
                of rrtText:
                    returnText &= returnVal.text
                else:
                    discard

            return (head, returnText, lambdaState)

    else:
        assert false

    return debugWrap(rule, se)

method translate(ch: Choice, context: LiltContext): Rule =
    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        for node in ch.contents:
            try:
                return translate(node, context)(head, text, lambdaState)
            except RuleError:
                discard
        raise newException(RuleError, "Didn't match any rule.")

    return debugWrap(rule, ch)

method translate(li: Literal, context: LiltContext): Rule =
    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        var head = head
        for ci in 0 ..< li.text.len:
            if li.text[ci] == text{head}:
                inc(head)
            else:
                raise newException(
                    RuleError,
                    "Code didn't match literal at char $1; expected '$2' but got '$3'." % [
                        $head, $li.text[ci], $text{head}
                    ]
                )
        return (head, li.text, lambdaState)

    return debugWrap(rule, li)

method translate(s: Set, context: LiltContext): Rule =
    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        let c = text{head}
        if c in s.charset:
            return (head + 1, $c, lambdaState)
        raise newException(RuleError, "'$1' not in $2." % [$c, $s])

    return debugWrap(rule, s)

method translate(o: Optional, context: LiltContext): Rule =
    let innerRule = translate(o.inner, context)
    var rule: proc(head: int, text: string, lambdaState: LambdaState): RuleVal

    if o.inner.returnType == rrtNone:
        rule = proc(head: int, text: string, lambdaState: LambdaState): RuleVal =
            return innerRule(head, text, lambdaState).hls

    else:
        rule = proc(head: int, text: string, lambdaState: LambdaState): RuleVal =
            try:
                return innerRule(head, text, lambdaState)
            except RuleError:
                case o.returnType:
                of rrtList:
                    return (head, newSeq[inner_ast.Node](), lambdaState)
                of rrtText:
                    return (head, "", lambdaState)
                else:
                    assert false

    return debugWrap(rule, o)

method translate(op: OnePlus, context: LiltContext): Rule =
    let innerRule = translate(op.inner, context)

    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        var head = head
        var lambdaState = lambdaState

        var matchedCount = 0

        var returnNodeList: seq[inner_ast.Node] = @[]
        var returnText = ""

        while true:
            var retVal: RuleVal
            try:
                retVal = innerRule(head, text, lambdaState)
            except RuleError:
                break

            (head, lambdaState) = retVal.hls

            case op.returnType:
            of rrtText:
                returnText &= retVal.text
            of rrtList:
                returnNodeList.add(retVal.node)
            of rrtNone:
                discard
            else:
                assert false

            inc(matchedCount)

        if matchedCount == 0:
            raise newException(RuleError, "Expected text to match at least once.")

        case op.returnType:
        of rrtList:
            return (head, returnNodeList, lambdaState)
        of rrtText:
            return (head, returnText, lambdaState)
        of rrtNone:
            return (head, lambdaState)
        else:
            assert false

    return debugWrap(rule, op)

method translate(g: Guard, context: LiltContext): Rule =
    let innerRule = translate(g.inner, context)

    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        try:
            discard innerRule(head, text, lambdaState)
        except RuleError:
            return (head, lambdaState)
        raise newException(RuleError, "Code matched guard inner rule.")

    return debugWrap(rule, g)

method translate(p: outer_ast.Property, context: LiltContext): Rule =
    let innerRule = translate(p.inner, context)

    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        var lambdaState = lambdaState
        var head = head

        let returnVal = innerRule(head, text, lambdaState)
        (head, lambdaState) = returnVal.hls
        lambdaState.node.properties[p.propName] = returnVal.toProperty

        return (head, lambdaState)
    
    return debugWrap(rule, p)

method translate(adj: Adjoinment, context: LiltContext): Rule =
    let innerRule = translate(adj.inner, context)

    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        var lambdaState = lambdaState
        let returnVal = innerRule(head, text, lambdaState)

        case returnVal.kind:
        of rrtText:
            lambdaState.text &= returnVal.text
        else:
            assert false

        return (returnVal.head, lambdaState)

    return debugWrap(rule, adj)


method translate(e: Extension, context: LiltContext): Rule =
    let innerRule = translate(e.inner, context)
    
    proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
        var lambdaState = lambdaState
        let returnVal = innerRule(head, text, lambdaState)

        case returnVal.kind:
        of rrtNode:
            lambdaState.list.add(returnVal.node)
        else:
            assert false

        return (returnVal.head, lambdaState)
   

    return debugWrap(rule, e)

proc translate*(prog: Program): LiltContext =
    ## Translates a program to a table of definitions
    var context = newTable[string, Rule]()
    for definition in prog.definitions.mapIt(it.Definition):
        context[definition.id] = translate(definition.body, context)
    return context

proc interpret*(text: string, ruleName: string, input: string): RuleVal =
    # Interprets a piece of Lilt code
    # Note that it does not complain if the chosen rule does not
    # consume all input text
    let ast: outer_ast.Node = parse.parseProgram(text)

    types.inferReturnTypes(ast)

    let definitions = translate(Program(ast))
    let rule: Rule = definitions[ruleName]
    
    let ruleVal = rule(0, input, initLambdaState(
        ast.Program
            .definitions.mapIt(it.Definition)
            .findIt(it.id == ruleName)
            .body.Lambda
            .returnType.toLiltType
    ))

    return ruleVal
