
#[ 

AST definiton for parsed Lilt code.

Each kind of node on the AST has its own Nim type.

All properties of subtypes of Node should be of type
Node, string, or seq[Node]
and should thus be returned in textProps,
nodeProps, or listProps.

]#

import sequtils
import strutils
import tables

import misc
import base

type RuleReturnType* = enum
    ## Rules may return any of a LiltType,
    ## or it may return nothing.
    # Default is rrtNone
    rrtNone

    rrtText
    rrtNode
    rrtList

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

type Node* = ref object of RootObj
    returnType*: RuleReturnType
    parent*: Node

method typeName*(n: Node): string {.base.} =
    # Returns the name of the type of the node
    raise new(BaseError)

method textProps*(n: Node): Table[string, string] {.base.} =
    return initTable[string, string]()

method nodeProps*(n: Node): Table[string, Node] {.base.} =
    return initTable[string, Node]()

method listProps*(n: Node): Table[string, seq[Node]] {.base.} =
    return initTable[string, seq[Node]]()

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

method typeName(p: Program): string = "Program"

# Reference

type Reference* = ref object of Node
    id*: string

proc newReference*(id: string): Reference =
    return Reference(id: id)

method textProps*(r: Reference): auto =
    return {"id": r.id}.toTable

method typeName(r: Reference): string = "Reference"

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

method typeName(d: Definition): string = "Definition"

# Lambda

type Lambda* = ref object of Node
    body*: Node  # Choice or sequence
    # If returning a node, we need to know the kind of the node
    # it's returning.
    returnNodeKind*: string

proc newLambda*(body: Node, returnNodeKind: string): Lambda =
    let la = Lambda(body: body, returnNodeKind: returnNodeKind)
    body.parent = la
    return la

proc newLambda*(body: Node): Lambda =
    return newLambda(body, nil)

method nodeProps*(la: Lambda): auto =
    return {"body": la.body}.toTable

method typeName(l: Lambda): string = "Lambda"

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

method typeName(s: Sequence): string = "Sequence"

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

method typeName(c: Choice): string = "Choice"

# Literal

type Literal* = ref object of Node
    text*: string

proc newLiteral*(text: string): Literal =
    return Literal(text: text)

method textProps*(li: Literal): auto =
    return {"text": li.text}.toTable

method typeName(li: Literal): string = "Literal"

# Set

type Set* = ref object of Node
    charset*: string

proc newSet*(charset: string): Set =
    return Set(charset: charset)

proc newSet*(charset: set[char]): Set =
    return newSet(charset.toString)

method textProps*(s: Set): auto =
    return {"characters": s.charset}.toTable

method typeName(s: Set): string = "Set"

# Optional

type Optional* = ref object of Node
    inner*: Node

proc newOptional*(inner: Node): Optional =
    let o = Optional(inner: inner)
    inner.parent = o
    return o

method nodeProps*(o: Optional): auto =
    return {"inner": o.inner}.toTable

method typeName(o: Optional): string = "Optional"

# OnePlus

type OnePlus* = ref object of Node
    inner*: Node

proc newOnePlus*(inner: Node): OnePlus =
    let op = OnePlus(inner: inner)
    inner.parent = op
    return op

method nodeProps*(op: OnePlus): auto =
    return {"inner": op.inner}.toTable

method typeName(op: OnePlus): string = "OnePlus"

# Guard

type Guard* = ref object of Node
    inner*: Node

proc newGuard*(inner: Node): Guard =
    let g = Guard(inner: inner)
    inner.parent = g
    return g

method nodeProps*(guard: Guard): auto =
    return {"inner": guard.inner}.toTable

method typeName(g: Guard): string = "Guard"

# Adjoinment

type Adjoinment* = ref object of Node
    inner*: Node

proc newAdjoinment*(inner: Node): Adjoinment =
    let a = Adjoinment(inner: inner)
    inner.parent = a
    return a

method nodeProps*(adj: Adjoinment): auto =
    return {"inner": adj.inner}.toTable

method typeName(adj: Adjoinment): string = "Adjoinment"

# Extension

type Extension* = ref object of Node
    inner*: Node

proc newExtension*(inner: Node): Extension =
    let e = Extension(inner: inner)
    inner.parent = e
    return e

method nodeProps*(ext: Extension): auto =
    return {"inner": ext.inner}.toTable

method typeName(ext: Extension): string = "Extension"

# Property

type Property* = ref object of Node
    propName*: string
    inner*: Node

proc newProperty*(name: string, inner: Node): Property =
    let p = Property(propName: name, inner: inner)
    inner.parent = p
    return p

method textProps*(prop: Property): auto =
    return {"name": prop.propName}.toTable

method nodeProps*(prop: Property): auto =
    return {"inner": prop.inner}.toTable

method typeName(p: Property): string = "Property"


#~#

proc `$`*(node: Node): string =
    var props = {"kind": node.typeName}.toTable
    for key, val in node.textProps:
        props[key] = val
    for key, val in node.nodeProps:
        props[key] = $val
    for key, val in node.listProps:
        props[key] = $val
    return $props

proc `$$`*(node: Node): string
proc `$$`(list: seq[Node]): string =
    result = "@[\n"
    for node in list:
        result &= >$ $$node & "\n"
    result &= "]"

proc `$$`*(node: Node): string =
    result = "{ kind: $1" % node.typeName
    result &= "\nrrt: $1" % $node.returnType
    for key, val in node.textProps:
        result &= "\n$1: $2" % [key, val]
    for key, val in node.nodeProps:
        result &= "\n$1:\n$2" % [key, >$ $$val]
    for key, val in node.listProps:
        result &= "\n$1: $2" % [key, $$val]
    result &= " }"

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
    ## NOTE: This does not verifiy that the two nodes' have matching
    ## return type. This is intentional.
    return node of other.type and other of node.type and  # Ensure of same type
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

proc scoped*(node: Node): seq[Node] =
    # Return all of node's descendants, except those contained
    # inside a Lambda contained inside the given node.
    result = node.children
    var head = 0  # Index of current node we're unpacking

    while head < result.len:
        let currentNode = result[head]
        if currentNode.isBranch and not (currentNode of Lambda):
            result.extend(currentNode.children)
        inc(head)
 