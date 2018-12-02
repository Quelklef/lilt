
#[
We define many of the types used throughout the project in this file.

We define them here chiefly in order to circumvent mutual dependencies;
doing it this was also offers a number of other benefits.
]#

import strfix
import strutils
import misc

import tables
import options

type
    #[
    Values in lilt may be only one of three types.
    Text, which is usually represented as `string`;
    Nodes, which are usually represented by a separate type (Node)
    and Lists (of nodes), which are typically represented by seq[Node]
    ]#
    LiltType* = enum
        # Values in Lilt may be of one of 3 types:
        ltText
        ltNode
        ltList

    LiltValue* = object
        case kind*: LiltType
        of ltText:
            text*: string
        of ltNode:
            node*: Node
        of ltList:
            list*: seq[Node]


    #[
    Type representing a Node on the generated AST.
    ]#
    Node* = object
        kind*: string
        # `source` is the bounds of the source code related to this node, inclusive
        source*: Slice[int]
        # Want properties to be mutable so that outer_ast.Property may modify it during runtime
        # TODO Should be immutable?
        properties*: TableRef[string, LiltValue]


    #[
    A rule is a function which takes the current head, text, and state, and:
        A) Consumes text, returning the new head
        B) Returns Text, a Node, or a List of Nodes, or othing (i.e. a Lilt value or nothing)
        C) Mutates the current lambdaState
        or D) Fails, raising a RuleError.
    ]#
    Rule* = proc(head: int, text: string, lambdaState: LiltValue): RuleVal
    RuleError* = object of Exception

    RuleVal* = object
        head*: int
        lambdaState*: LiltValue
        val*: Option[LiltValue]

    #[
    The final level of abstraction is that of a Parser, which
    accepts a bit of code and returns a Lilt value.
    We know that it can return a lilt value since lambdas never
    return any ltNone
    ]#
    Parser* = proc(text: string): LiltValue

proc `==`*(item, other: LiltValue): bool =
    if item.kind != other.kind:
        return false

    let kind = item.kind
    case kind:
    of ltText:
        return item.text == other.text
    of ltNode:
        return item.node == other.node
    of ltList:
        return item.list == other.list

proc initLiltValue*(kind: LiltType): LiltValue =
    case kind:
    of ltText:
        result = LiltValue(kind: ltText, text: "")
    of ltList:
        result = LiltValue(kind: ltList, list: @[])
    of ltNode:
        # The kind will be added in the top-leve sequence
        result = LiltValue(kind: ltNode, node: Node(kind: "", properties: newTable[string, LiltValue]()))
    else:
        assert false

proc initLiltValue*(text: string): LiltValue =
    return LiltValue(kind: ltText, text: text)

proc initLiltValue*(node: Node): LiltValue =
    return LiltValue(kind: ltNode, node: node)

proc initLiltValue*(list: seq[Node]): LiltValue =
    return LiltValue(kind: ltList, list: list)

# Define the following because it is file-agnostic and needs to be defined
# here in order to avoid mutual dependencies

const escapeChar = '\\'
const staticEscapes = {
    '\\': '\\',
    '\'': '\'',
    '"': '\"',
    '>': '>',
    't': '\t',
    'r': '\r',
    'c': '\c',
    'l': '\l',
    'a': '\a',
    'b': '\b',
    'e': '\e',
}
let staticEscapesTable = staticEscapes.toTable
let invertedStaticEscapesTable = staticEscapes.invert.toTable

proc liltUnescape*(s: string): string =
    result = ""
    var head = 0
    while head < s.len:
        if s{head} == escapeChar:
            let next = s{head + 1}
            if next in staticEscapesTable:
                result &= staticEscapesTable[next]
                inc(head, 2)
            else:
                if next == 'x':
                    let hex1 = s{head + 2}
                    if hex1 == '\0':
                        raise newException(ValueError, "\\xHH requires 2 digits, got 0.")
                    let hex2 = s{head + 3}
                    if hex2 == '\0':
                        raise newException(ValueError, "\\xHH requires 2 digits, got 1.")

                    let value = unescape(s[head .. head + 3], prefix="", suffix="")
                    result &= value
                    inc(head, 4)
                else:
                    raise newException(ValueError, "Invalid escape '$1'" % s[head .. head + 1])
        else:
            result &= s{head}
            inc(head)

const unprintables = {'\0'..'\31', '\127'..'\255'}
proc liltEscape*(s: string): string =
    result = ""
    var head = 0
    while head < s.len:
        if s{head} in invertedStaticEscapesTable:
            result &= escapeChar & invertedStaticEscapesTable[s{head}]
            inc(head)
        elif s{head} in unprintables:
            result &= strutils.escape($s{head}, prefix="", suffix="")
        else:
            result &= s{head}
            inc(head)
