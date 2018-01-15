#[ 
AST definiton for parsed Lilt code.
]#

#[
Each kind of node on the AST, e.g. ADD_OP, FUNC_DEF, etc.
has its own type.

They should all inherit from Node and should
fulfill the following contract:

method children: seq[Node]
    return all children of the node
    if no children, return @[]

method textProps: Table[string, string]
    return all string properties

method nodeProps: Table[string, Node]
    return all node properties

method listProps: Table[string, seq[Node]]
    take a guess


Note that everything is a "ref object of" rather than an "object of"
This is because it's needed for the polymorphism to work
for some reason...

All properties of subtypes of Node should be of type
Node, string, or seq[Node]
and should thus be returned in textProps,
nodeProps, or listProps.

]#

import sequtils
import strutils
import tables
import typetraits

import misc

type RuleReturnType* = enum
    rrtUnknown
    rrtTypeless

    rrtText
    rrtNode
    rrtList

type Node* = ref object of RootObj
    returnType*: RuleReturnType
    parent*: Node

proc colloqType(n: Node): string =
    # Returns the name of the type of the node
    return n.type.name

method textProps*(n: Node): Table[string, string] {.base.} =
    return initTable[string, string]()

method nodeProps*(n: Node): Table[string, Node] {.base.} =
    return initTable[string, Node]()

method listProps*(n: Node): Table[string, seq[Node]] {.base.} =
    return initTable[string, seq[Node]]()

proc `$`*(node: Node): string  # Forward dec. for following proc
proc getPropsAsStrings(node: Node): Table[string, string] =
    # Return all properties of a node, as strings
    # returns property "kind"
    var props = {"kind": node.colloqType}.toTable
    for key, val in node.textProps:
        props[key] = val
    for key, val in node.nodeProps:
        props[key] = $val
    for key, val in node.listProps:
        props[key] = $val
    return props

proc `$`*(node: Node): string =
    return $node.getPropsAsStrings

proc `$$`*(node: Node): string =
    return $$node.getPropsAsStrings

proc children*(n: Node): seq[Node] =
    result = @[]
    for node in n.nodeProps.values:
        result.add(node)
    for list in n.listProps.values:
        result.extend(list)

proc isBranch*(n: Node): bool =
    return n.children.len > 0

proc isLeaf*(n: Node): bool =
    return not n.isBranch

proc `==`*(node: Node, other: Node): bool =
    # NOTE: This does not verifiy that the two nodes' have matching
    # return type. This is intentional.
    # TODO: This should not rely on .colloqType.
    # There must be another way to check if two nodes are of the same type.
    return node.colloqType == other.colloqType and
        node.textProps == other.textProps and
        node.nodeProps == other.nodeProps and
        node.listProps == other.listProps

proc descendants*(node: Node): seq[Node] =
  ## Recursively iterates through all descendants of given node.
  
  result = node.children
  var head = 0  # Index of current node we're unpacking

  while head < result.len:
    let current_node = result[head]
    if current_node.isBranch:
      result.extend(current_node.children)
    inc(head)

proc layers*(node: Node): seq[seq[Node]] =
    ## Returns a 2d list in which each sublist is one more level
    ## deep than the previous.
    ## For instance, [PROGRAM [DEFINITION [SEQUENCE
    ##     [SET 'abc']
    ##     [GUARD [CHOICE [LITERAL 'a'] [LITERAL 'b']]
    ##     [OPTIONAL [LITERAL 'c']]
    ## ]]]
    ## will return @[
    ##     @[PROGRAM],
    ##     @[DEFINITION],
    ##     @[SEQUENCE],
    ##     @[SET, GUARD, OPTIONAL],
    ##     @[CHOICE, LITERAL 'c'],
    ##     @[LITERAL 'a'],
    ##     @[LITERAL 'b']
    ## ]
    result = @[@[node]]
    while true:
        let prevLayer = result[result.len - 1]
        var newLayer: seq[Node] = @[]

        for node in prevLayer:
            newLayer.extend(node.children)

        if newLayer.len == 0:
            break
        else:
            result.add(newLayer)

proc ancestors*(node: Node): seq[Node] =
    result = @[]
    var curNode = node.parent
    while not curNode.isNil:
        result.add(curNode)
        curNode = curNode.parent

# Program

type Program* = ref object of Node
    definitions*: seq[Node]

proc newProgram*(dfns: seq[Node]): Program =
    let p = Program(definitions: dfns)
    for dfn in dfns:
        dfn.parent = p
    return p

method listProps*(p: Program): auto =
    return {"definitions": p.definitions}.toTable

# Reference

type Reference* = ref object of Node
    id*: string

proc newReference*(id: string): Reference =
    return Reference(id: id)

method textProps*(r: Reference): auto =
    return {"id": r.id}.toTable

# Definition

type Definition* = ref object of Node
    id*: string
    body*: Node

proc newDefinition*(id: string, body: Node): Definition =
    let d = Definition(id: id, body: body)
    body.parent = d
    return d

method textProps*(def: Definition): auto =
    return {"id": def.id}.toTable

method nodeProps*(def: Definition): auto =
    return {"body": def.body}.toTable

# Sequence

type Sequence* = ref object of Node
    contents*: seq[Node]

proc newSequence*(cts: seq[Node]): Sequence =
    let s = Sequence(contents: cts)
    for node in s.contents:
        node.parent = s
    return s

method listProps*(s: Sequence): auto =
    return {"contents": s.contents}.toTable

# Choice

type Choice* = ref object of Node
    contents*: seq[Node]

proc newChoice*(cts: seq[Node]): Choice =
    let c = Choice(contents: cts)
    for node in cts:
        node.parent = c
    return c

method listProps*(c: Choice): auto =
    return {"contents": c.contents}.toTable

# Literal

type Literal* = ref object of Node
    text*: string

proc newLiteral*(text: string): Literal =
    return Literal(text: text)

method textProps*(li: Literal): auto =
    return {"text": li.text}.toTable

# Set

type Set* = ref object of Node
    charset*: string

proc newSet*(charset: string): Set =
    return Set(charset: charset)

method textProps*(s: Set): auto =
    return {"characters": s.charset}.toTable

# Optional

type Optional* = ref object of Node
    inner*: Node

proc newOptional*(inner: Node): Optional =
    let o = Optional(inner: inner)
    inner.parent = o
    return o

method nodeProps*(o: Optional): auto =
    return {"inner": o.inner}.toTable

# OnePlus

type OnePlus* = ref object of Node
    inner*: Node

proc newOnePlus*(inner: Node): OnePlus =
    let op = OnePlus(inner: inner)
    inner.parent = op
    return op

method nodeProps*(op: OnePlus): auto =
    return {"inner": op.inner}.toTable

# Guard

type Guard* = ref object of Node
    inner*: Node

proc newGuard*(inner: Node): Guard =
    let g = Guard(inner: inner)
    inner.parent = g
    return g

method nodeProps*(guard: Guard): auto =
    return {"inner": guard.inner}.toTable

# Extension

type Extension* = ref object of Node
    inner*: Node

proc newExtension*(inner: Node): Extension =
    let e = Extension(inner: inner)
    inner.parent = e
    return e

method nodeProps*(ext: Extension): auto =
    return {"inner": ext.inner}.toTable

# Property

type Property* = ref object of Node
    propName*: string
    inner*: Node

proc newProperty*(name: string, inner: Node): Property =
    let p = Property(propName: name, inner: inner)
    inner.parent = p
    return p

method textprops*(prop: Property): auto =
    return {"name": prop.propName}.toTable

method nodeProps*(prop: Property): auto =
    return {"inner": prop.inner}.toTable
