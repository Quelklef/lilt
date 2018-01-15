#[
Definiton of the AST _inside_ Lilt;
that is, the AST which is a Lilt construct;
that is, the AST used when _running_ Lilt code.

Lilt nodes are either code (atoms / leaves), which contain only raw code,
or branches, which tonain:
    - A kind*, which is conteptually an enumeration but
        represented as a string
    - A table of properties, from string to Node
    - A sequence of children
]#

import tables
import strutils
import sequtils

import misc

type
    PropertyKind* = enum
        pkText, pkNode, pkList

    # Type of an property on a node
    # Each property can either be text, a node, or a list of nodes
    Property* = object
        case kind: PropertyKind
        of pkText:
            text*: string
        of pkNode:
            node*: Node
        of pkList:
            # Children
            list*: seq[Node]

    Node* = object
        kind*: string
        # Want properties to be mutable for statements
        properties*: TableRef[string, Property]

proc `$`*(p: Property): string

proc `==`*(prop: Property, other: Property): bool =
    if prop.kind != other.kind:
        return false

    case prop.kind:
    of pkText:
        return prop.text == other.text
    of pkNode:
        return prop.node == other.node
    of pkList:
        return prop.list == other.list

proc `==`*(node: Node, other: Node): bool =
    return node.properties == other.properties

proc `$`*(node: Node): string =
    var props = {"kind": node.kind}.toTable
    for key, val in node.properties:
        props[key] = $val
    return $props

proc `$$`*(node: Node): string =
    var props = {"kind": node.kind}.toTable
    for key, val in node.properties:
        props[key] = $val
    return $$props

proc `$$`*(s: seq[Node]): string =
    return "@[\n$1\n]" % >$ s.mapIt($$it).join("\n")

proc `$`*(p: Property): string =
    # TODO Should be `$$`

    var val: string
    case p.kind:
    of pkText:
        val = p.text
    of pkNode:
        val = $p.node
    of pkList:
        val = $$p.list

    return "<\n$1\n>" % >$ (
        "$1\n$2" % [
            "kind: $1" % $p.kind,
            "val: $1" % val
        ]
    )

#~#

proc initProperty*(text: string): Property =
    return Property(kind: pkText, text: text)

proc initProperty*(node: Node): Property =
    return Property(kind: pkNode, node: node)

proc initProperty*(list: seq[Node]): Property =
    return Property(kind: pkList, list: list)

proc initNode*(kind: string): Node =
    return Node(kind: kind, properties: newTable[string, Property]())

proc initNode*(kind: string, props: TableRef[string, Property]): Node =
    return Node(kind: kind, properties: props)

proc initNode*(kind: string, props: Table[string, Property]): Node =
    # No idea how this works, just paralleling code from table.nim source
    var t: TableRef[string, Property]
    new(t)
    t[] = props
    return Node(kind: kind, properties: t)

proc initNode*(kind: string, props: openarray[(string, Property)]): Node =
    return Node(kind: kind, properties: props.newTable)

proc initNode*(kind: string, props: openarray[(string, string)]): Node =
    let properties = @props.mapIt( (it[0], Property(kind: pkText, text: it[1])) ).newTable
    return Node(kind: kind, properties: properties)

proc initNode*(kind: string, props: openarray[(string, Node)]): Node =
    let properties = @props.mapIt( (it[0], Property(kind: pkNode, node: it[1])) ).newTable
    return Node(kind: kind, properties: properties)

proc initNode*(kind: string, props: openarray[(string, seq[Node])]): Node =
    let properties = @props.mapIt( (it[0], Property(kind: pkList, list: it[1])) ).newTable
    return Node(kind: kind, properties: properties)
