
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
import sequtils

import outer_ast
import inner_ast
import verify
import strfix
import parse
import types
import base

#[
Most Lilt constructs are translated into Rules,
which are functions which take code and either
a) return an integer, the amount of code consumed,
or b) fail. (Sound familiar?)

Failing is done by raising a RuleError.
]#

type
    RuleVal* = object of RootObj
        head: int
        currentResult: CurrentResult

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
    Each new reference / run of a definiton's rule makes a new CurrentResult.
    This CurrentResult is what the statements in the rule modifies.
    ]#
    CurrentResult* = object of RootObj
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

proc hcr(rv: RuleVal): (int, CurrentResult) =
    # No semantic meaning, exists only to make code terser
    return (rv.head, rv.currentResult)

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

converter toRuleVal(retVal: (int, string, CurrentResult)): RuleVal =
    return RuleVal(
        kind: rrtText,
        head: retVal[0],
        text: retVal[1],
        currentResult: retVal[2],
    )

converter toRuleVal(retVal: (int, seq[inner_ast.Node], CurrentResult)): RuleVal =
    return RuleVal(
        kind: rrtList,
        head: retVal[0],
        list: retVal[1],
        currentResult: retVal[2],
    )

converter toRuleval(retVal: (int, inner_ast.Node, CurrentResult)): RuleVal =
    return RuleVal(
        kind: rrtNode,
        head: retVal[0],
        node: retVal[1],
        currentResult: retVal[2],
    )

converter toRuleVal(retVal: (int, CurrentResult)): RuleVal =
    return RuleVal(
        kind: rrtNone,
        head: retVal[0],
        currentResult: retVal[1],
    )

proc initCurrentResult*(kind: LiltType): CurrentResult =
    case kind:
    of ltText:
        result = CurrentResult(kind: ltText, text: "")
    of ltList:
        result = CurrentResult(kind: ltList, list: @[])
    of ltNode:
        # The kind will be added in the top-leve sequence
        result = CurrentResult(kind: ltNode, node: inner_ast.initNode(""))
    else:
        assert false

type Rule* = proc(head: int, text: string, currentResult: CurrentResult): RuleVal
type RuleError = object of Exception

type LiltContext* = TableRef[string, Rule]

const doDebug = true
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
        proc wrappedRule(head: int, text: string, currentResult: CurrentResult): RuleVal =
            #debugPush("Attempting to match\n$1\nwith:\n$2" % [$node, code[head ..< code.len]])
            debugPush("Attempting to match $1" % $node)
            #discard readLine(stdin)
            try:
                result = rule(head, code, currentResult)
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

method translate(re: Reference, context: LiltContext): Rule =
    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
        # Each time a rule is referenced, it relies on its own separate current result
        let returnVal = context[re.id](head, text, initCurrentResult(re.returnType.toLiltType))

        case returnVal.kind:
        of rrtText:
            return (returnVal.head, returnVal.text, currentResult)
        of rrtNode:
            return (returnVal.head, returnVal.node, currentResult)
        of rrtList:
            return (returnVal.head, returnVal.list, currentResult)
        of rrtNone:
            return (returnVal.head, currentResult)

    return debugWrap(rule, re)

method translate(se: Sequence, context: LiltContext): Rule =
    let isTopLevel = se.parent of Definition
    var rule: proc(head: int, text: string, currentResult: CurrentResult): RuleVal

    case se.returnType:
    of rrtText:
        # TODO: This should not be handled here.
        # evidently, typing is insufficient
        # Perhaps intents are a good idea
        let hasAdj = se.descendants.filterIt(it of Adjoinment).len > 0

        if hasAdj:
            rule = proc(head: int, text: string, currentResult: CurrentResult): RuleVal =
                var currentResult = currentResult
                var head = head
                var returnText = ""

                for node in se.contents:
                    (head, currentResult) = translate(node, context)(head, text, currentResult).hcr

                return (head, currentResult.text, currentResult)

        else:
            rule = proc(head: int, text: string, currentResult: CurrentResult): RuleVal =
                var head = head
                var currentResult = currentResult
                
                var returnText = ""

                for node in se.contents:
                    let returnVal = translate(node, context)(head, text, currentResult)
                    (head, currentResult) = returnVal.hcr

                    case returnVal.kind:
                    of rrtText:
                        returnText &= returnVal.text
                    of rrtNone:
                        discard
                    else:
                        assert false

                return (head, returnText, currentResult)

    of rrtNode:
        assert isTopLevel
        rule = proc(head: int, text: string, currentResult: CurrentResult): RuleVal =
            var head = head
            var currentResult = currentResult

            for node in se.contents:
                (head, currentResult) = translate(node, context)(head, text, currentResult).hcr

            assert currentResult.kind == ltNode
            currentResult.node.kind = se.parent.Definition.id
            return (head, currentResult.node, currentResult)
    
    of rrtList:
        assert isTopLevel
        rule = proc(head: int, text: string, currentResult: CurrentResult): RuleVal =
            var head = head
            var currentResult = currentResult

            for node in se.contents:
                let returnVal = translate(node, context)(head, text, currentResult)
                (head, currentResult) = returnVal.hcr

            return (head, currentResult.list, currentResult)

    else:
        assert false

    return debugWrap(rule, se)

method translate(ch: Choice, context: LiltContext): Rule =
    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
        for node in ch.contents:
            try:
                return translate(node, context)(head, text, currentResult)
            except RuleError:
                discard
        raise newException(RuleError, "Didn't match any rule.")

    return debugWrap(rule, ch)

method translate(li: Literal, context: LiltContext): Rule =
    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
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
        return (head, li.text, currentResult)

    return debugWrap(rule, li)

method translate(s: Set, context: LiltContext): Rule =
    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
        let c = text{head}
        if c in s.charset:
            return (head + 1, $c, currentResult)
        raise newException(RuleError, "'$1' not in $2." % [$c, $s])

    return debugWrap(rule, s)

#[
Optional rules have different behaviour based on their inner rule.
Depending on the return type of the inner rule, the optional rule
will default to returning different things if the inner rule fails.
Inner rule return type -> optional return vail on inner rule failure
code -> ""
list -> []
node -> nilNode
]#
method translate(o: Optional, context: LiltContext): Rule =
    let innerRule = translate(o.inner, context)
    var rule: proc(head: int, text: string, currentResult: CurrentResult): RuleVal

    if o.inner.returnType in [rrtNone, rrtNode]:
        rule = proc(head: int, text: string, currentResult: CurrentResult): RuleVal =
            return innerRule(head, text, currentResult).hcr

    else:
        rule = proc(head: int, text: string, currentResult: CurrentResult): RuleVal =
            try:
                return innerRule(head, text, currentResult)
            except RuleError:
                case o.returnType:
                of rrtList:
                    return (head, newSeq[inner_ast.Node](), currentResult)
                of rrtText:
                    return (head, "", currentResult)
                else:
                    assert false

    return debugWrap(rule, o)

method translate(op: OnePlus, context: LiltContext): Rule =
    let innerRule = translate(op.inner, context)

    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
        var head = head
        var currentResult = currentResult

        var matchedCount = 0

        var returnNodeList: seq[inner_ast.Node] = @[]
        var returnText = ""

        while true:
            var retVal: RuleVal
            try:
                retVal = innerRule(head, text, currentResult)
            except RuleError:
                break

            (head, currentResult) = retVal.hcr

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
            return (head, returnNodeList, currentResult)
        of rrtText:
            return (head, returnText, currentResult)
        of rrtNone:
            return (head, currentResult)
        else:
            assert false

    return debugWrap(rule, op)

method translate(g: Guard, context: LiltContext): Rule =
    let innerRule = translate(g.inner, context)

    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
        try:
            discard innerRule(head, text, currentResult)
        except RuleError:
            return (head, currentResult)
        raise newException(RuleError, "Code matched guard inner rule.")

    return debugWrap(rule, g)

method translate(p: outer_ast.Property, context: LiltContext): Rule =
    let innerRule = translate(p.inner, context)

    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
        let returnVal = innerRule(head, text, currentResult)

        var crNode: inner_ast.Node
        case currentResult.kind:
        of ltNode:
            crNode = currentResult.node
        else:
            assert false

        crNode.properties[p.propName] = returnVal.toProperty
        return returnVal.hcr
    
    return debugWrap(rule, p)

method translate(adj: Adjoinment, context: LiltContext): Rule =
    let innerRule = translate(adj.inner, context)

    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
        var currentResult = currentResult
        let returnVal = innerRule(head, text, currentResult)

        case returnVal.kind:
        of rrtText:
            currentResult.text &= returnVal.text
        else:
            assert false

        return (returnVal.head, currentResult)

    return debugWrap(rule, adj)


method translate(e: Extension, context: LiltContext): Rule =
    let innerRule = translate(e.inner, context)
    
    proc rule(head: int, text: string, currentResult: CurrentResult): RuleVal =
        var currentResult = currentResult
        let returnVal = innerRule(head, text, currentResult)

        case returnVal.kind:
        of rrtNode:
            currentResult.list.add(returnVal.node)
        else:
            assert false

        return (returnVal.head, currentResult)
   

    return debugWrap(rule, e)

proc translate(prog: Program): LiltContext =
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
    verify.verify(ast)
    types.inferReturnTypes(ast)
    echo $$ast
    let res = translate(Program(ast))
    let rule: Rule = res[ruleName]
    echo ruleName
    echo ast.Program.definitions.filterit(it.Definition.id == ruleName)[0].returnType.toLiltType
    result = rule(0, input, initCurrentResult(
        ast.Program
            .definitions
            .filterIt(it.Definition.id == ruleName)[0]  # TODO: For some reason, .findIt not working??
            .returnType.toLiltType
    ))

when isMainModule:
    const code = r"""
    sentence: &word *[", " &word]
    word: val=*<abcdefghijklmnopqrstuvwxyz>
    """

    block:
        let ast = parseProgram(code)
        verify(ast)
        inferReturnTypes(ast)
        echo $$ast

    #echo $$interpret(code, "word", "test").node
    echo $$interpret(code, "sentence", "several, words, in, a, sentence").list
