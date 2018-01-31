
#[
We define many of the types used throughout the project in this file.

We define them here chiefly in order to circumvent mutual dependencies;
doing it this was also offers a number of other benefits.
]#

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

proc `==`(item, other: LiltValue): bool =
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