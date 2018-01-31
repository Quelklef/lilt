
#[
We define many of the types used throughout the project in this file.

We define them here chiefly in order to circumvent mutual dependencies;
doing it this was also offers a number of other benefits.
]#

import tables

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


    #[
    Type representing a Node on the generated AST.
    ]#
    Node* = object
        kind*: string
        # Want properties to be mutable so that outer_ast.Property may modify it during runtime
        # TODO: Once states become immutable, this should, too
        properties*: TableRef[string, Property]

    # A property on a node.
    # Each property may be any Lilt value, e.g. text, a node, or a list of nodes
    Property* = object
        case kind*: LiltType
        of ltText:
            text*: string
        of ltNode:
            node*: Node
        of ltList:
            # Children
            list*: seq[Node]


    #[
    A rule is a function which takes the current head, text, and state, and:
        A) Consumes text, returning the new head
        B) Returns Text, a Node, or a List of Nodes, or othing (i.e. a Lilt value or nothing)
        C) Mutates the current lambdaState
        or D) Fails, raising a RuleError.
    ]#
    # TODO are mutations gonna work weird with failing optionals? lambdaState should
    # probably be immutable as well
    # TODO: Implement LiltValue then
    #       replace RuleVal with tuple[head: int, state: LambdaState, val: Option[LiltValue]]
    Rule* = proc(head: int, text: string, lambdaState: LambdaState): RuleVal
    RuleError* = object of Exception

    #[
    Rules may return any of a LiltType, or nothing
    ]#
    RuleReturnType* = enum
        rrtNone
        rrtText
        rrtNode
        rrtList

    RuleVal* = object of RootObj
        head*: int
        lambdaState*: LambdaState

        case kind*: RuleReturnType:
        of rrtText:
            text*: string
        of rrtNode:
            node*: Node
        of rrtList:
            list*: seq[Node]
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
            node*: Node
        of ltList:
            list*: seq[Node]


proc toLiltType*(rrt: RuleReturnType): LiltType =
    case rrt:
    of rrtNone:
        raise newException(ValueError, "Value cannot be rrtNone.")
    of rrtText:
        return ltText
    of rrtNode:
        return ltNode
    of rrtList:
        return ltList
