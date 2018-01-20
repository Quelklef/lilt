
#[
Definiton of the AST _inside_ Lilt;
that is, the AST which is a Lilt construct;
that is, the AST used when _running_ Lilt code.
]#

import tables
import strutils
import sequtils

import misc
import base

import json

type
    # Type of an property on a node
    # Each property can either be text, a node, or a list of nodes
    Property* = object
        case kind*: LiltType
        of ltText:
            text*: string
        of ltNode:
            node*: Node
        of ltList:
            # Children
            list*: seq[Node]

    Node* = object
        kind*: string
        # Want properties to be mutable so that Property may modify it during runtime
        properties*: TableRef[string, Property]

proc `==`*(prop: Property, other: Property): bool =
    if prop.kind != other.kind:
        return false

    case prop.kind:
    of ltText:
        return prop.text == other.text
    of ltNode:
        return prop.node == other.node
    of ltList:
        return prop.list == other.list

proc `==`*(node: Node, other: Node): bool =
    return node.properties == other.properties

proc toJson*(node: Node): JsonNode
proc `$`*(node: Node): string =
    return $node.toJson
proc `$$`*(node: Node): string =
    return node.toJson.pretty

#~# JSON backend #~#

# TODO: After bootstrapping starts, the type definitions in this file
# should be moved to ast.nim
# The procs should be moved to astutils.nim or something
# and this should be moved to toJson.nim or something

proc seqToJsonNode(se: seq[JsonNode]): JsonNode =
    result = newJArray()
    result.elems = se

proc toJson(prop: Property): JsonNode =
    case prop.kind:
    of ltText:
        return %prop.text
    of ltNode:
        return toJson(prop.node)
    of ltList:
        return prop.list.map(toJson).seqToJsonNode

proc toJson*(node: Node): JsonNode =
    result = newJObject()
    result.fields["kind"] = % node.kind

    for key, prop in node.properties:
        result.fields[key] = toJson(prop)

#~#

proc initProperty*(text: string): Property =
    return Property(kind: ltText, text: text)

proc initProperty*(node: Node): Property =
    return Property(kind: ltNode, node: node)

proc initProperty*(list: seq[Node]): Property =
    return Property(kind: ltList, list: list)

proc initNode*(kind: string): Node =
    return Node(kind: kind, properties: newTable[string, Property]())

proc initNode*(kind: string, props: TableRef[string, Property]): Node =
    return Node(kind: kind, properties: props)

proc initNode*(kind: string, props: openarray[(string, Property)]): Node =
    return Node(kind: kind, properties: props.newTable)

proc initNode*(kind: string, props: openarray[(string, string)]): Node =
    let properties = @props.mapIt( (it[0], Property(kind: ltText, text: it[1])) ).newTable
    return Node(kind: kind, properties: properties)

proc initNode*(kind: string, props: openarray[(string, Node)]): Node =
    let properties = @props.mapIt( (it[0], Property(kind: ltNode, node: it[1])) ).newTable
    return Node(kind: kind, properties: properties)

proc initNode*(kind: string, props: openarray[(string, seq[Node])]): Node =
    let properties = @props.mapIt( (it[0], Property(kind: ltList, list: it[1])) ).newTable
    return Node(kind: kind, properties: properties)

#[ TODO
It would be really nice to have a Json-%*-esque macro or other
API to be able to easily write ASTs without having to deal with
a million unreadable calls to initNode and initProperty
]#
