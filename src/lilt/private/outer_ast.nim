
#[ 

AST definiton for parsed Lilt code.

Each kind of Node on the AST has its own Nim type.

All properties of subtypes of ONode should be of type
Node, string, or seq[Node]
and should thus be returned in textProps,
nodeProps, or listProps.

]#

import sequtils
import strutils
import tables

import misc
import base

# We call this ONode just to differentiate it from base.Node
type ONode* = ref object of RootObj
    returnType*: RuleReturnType
    parent*: ONode


method typeName*(n: ONode): string {.base.} =
    # Returns the name of the type of the ONode
    raise new(BaseError)

method textProps*(n: ONode): Table[string, string] {.base.} =
    return initTable[string, string]()

method nodeProps*(n: ONode): Table[string, ONode] {.base.} =
    return initTable[string, ONode]()

method listProps*(n: ONode): Table[string, seq[ONode]] {.base.} =
    return initTable[string, seq[ONode]]()

# Program

type Program* = ref object of ONode
    definitions*: seq[ONode]

proc newProgram*(dfns: seq[ONode]): Program =
    let p = Program(definitions: dfns)
    for dfn in dfns:
        dfn.parent = p
    return p

method listProps*(p: Program): auto =
    return {"definitions": p.definitions}.toTable

method typeName(p: Program): string = "Program"

# Reference

type Reference* = ref object of ONode
    id*: string

proc newReference*(id: string): Reference =
    return Reference(id: id)

method textProps*(r: Reference): auto =
    return {"id": r.id}.toTable

method typeName(r: Reference): string = "Reference"

# Definition

type Definition* = ref object of ONode
    id*: string
    body*: ONode

proc newDefinition*(id: string, body: ONode): Definition =
    let d = Definition(id: id, body: body)
    body.parent = d
    return d

method textProps*(def: Definition): auto =
    return {"id": def.id}.toTable

method nodeProps*(def: Definition): auto =
    return {"body": def.body}.toTable

method typeName(d: Definition): string = "Definition"

# Lambda

type Lambda* = ref object of ONode
    body*: ONode  # Choice or sequence
    # If returning a ONode, we need to know the kind of the ONode
    # it's returning.
    returnNodeKind*: string

proc newLambda*(body: ONode, returnNodeKind: string): Lambda =
    let la = Lambda(body: body, returnNodeKind: returnNodeKind)
    body.parent = la
    return la

proc newLambda*(body: ONode): Lambda =
    return newLambda(body, "<anonymous>")

method nodeProps*(la: Lambda): auto =
    return {"body": la.body}.toTable

method typeName(l: Lambda): string = "Lambda"

# Sequence

type Sequence* = ref object of ONode
    contents*: seq[ONode]

proc newSequence*(cts: seq[ONode]): Sequence =
    let s = Sequence(contents: cts)
    for ONode in s.contents:
        ONode.parent = s
    return s

method listProps*(s: Sequence): auto =
    return {"contents": s.contents}.toTable

method typeName(s: Sequence): string = "Sequence"

# Choice

type Choice* = ref object of ONode
    contents*: seq[ONode]

proc newChoice*(cts: seq[ONode]): Choice =
    let c = Choice(contents: cts)
    for ONode in cts:
        ONode.parent = c
    return c

method listProps*(c: Choice): auto =
    return {"contents": c.contents}.toTable

method typeName(c: Choice): string = "Choice"

# Literal

type Literal* = ref object of ONode
    text*: string

proc newLiteral*(text: string): Literal =
    return Literal(text: text)

method textProps*(li: Literal): auto =
    return {"text": li.text}.toTable

method typeName(li: Literal): string = "Literal"

# Set

type Set* = ref object of ONode
    charset*: string

proc newSet*(charset: string): Set =
    return Set(charset: charset)

proc newSet*(charset: set[char]): Set =
    return newSet(charset.toString)

method textProps*(s: Set): auto =
    return {"characters": s.charset}.toTable

method typeName(s: Set): string = "Set"

# Optional

type Optional* = ref object of ONode
    inner*: ONode

proc newOptional*(inner: ONode): Optional =
    let o = Optional(inner: inner)
    inner.parent = o
    return o

method nodeProps*(o: Optional): auto =
    return {"inner": o.inner}.toTable

method typeName(o: Optional): string = "Optional"

# OnePlus

type OnePlus* = ref object of ONode
    inner*: ONode

proc newOnePlus*(inner: ONode): OnePlus =
    let op = OnePlus(inner: inner)
    inner.parent = op
    return op

method nodeProps*(op: OnePlus): auto =
    return {"inner": op.inner}.toTable

method typeName(op: OnePlus): string = "OnePlus"

# Guard

type Guard* = ref object of ONode
    inner*: ONode

proc newGuard*(inner: ONode): Guard =
    let g = Guard(inner: inner)
    inner.parent = g
    return g

method nodeProps*(guard: Guard): auto =
    return {"inner": guard.inner}.toTable

method typeName(g: Guard): string = "Guard"

# Adjoinment

type Adjoinment* = ref object of ONode
    inner*: ONode

proc newAdjoinment*(inner: ONode): Adjoinment =
    let a = Adjoinment(inner: inner)
    inner.parent = a
    return a

method nodeProps*(adj: Adjoinment): auto =
    return {"inner": adj.inner}.toTable

method typeName(adj: Adjoinment): string = "Adjoinment"

# Extension

type Extension* = ref object of ONode
    inner*: ONode

proc newExtension*(inner: ONode): Extension =
    let e = Extension(inner: inner)
    inner.parent = e
    return e

method nodeProps*(ext: Extension): auto =
    return {"inner": ext.inner}.toTable

method typeName(ext: Extension): string = "Extension"

# Property

type Property* = ref object of ONode
    propName*: string
    inner*: ONode

proc newProperty*(name: string, inner: ONode): Property =
    let p = Property(propName: name, inner: inner)
    inner.parent = p
    return p

method textProps*(prop: Property): auto =
    return {"name": prop.propName}.toTable

method nodeProps*(prop: Property): auto =
    return {"inner": prop.inner}.toTable

method typeName(p: Property): string = "Property"


#~#

proc `$`*(ONode: ONode): string =
    result = "{kind: $1, " % ONode.typeName
    result &= "rrt: $1, " % $ONode.returnType
    for key, val in ONode.textProps:
        result &= "$1: $2, " % [key, val]
    for key, val in ONode.nodeProps:
        result &= "$1: $2, " % [key, $val]
    for key, val in ONode.listProps:
        result &= "$1: $2" % [key, $val]
    result &= "}"

proc `$$`*(ONode: ONode): string
proc `$$`(list: seq[ONode]): string =
    result = "@[\n"
    for ONode in list:
        result &= >$ $$ONode & "\n"
    result &= "]"

proc `$$`*(ONode: ONode): string =
    result = "{ kind: $1" % ONode.typeName
    result &= "\nrrt: $1" % $ONode.returnType
    for key, val in ONode.textProps:
        result &= "\n$1: $2" % [key, val]
    for key, val in ONode.nodeProps:
        result &= "\n$1:\n$2" % [key, >$ $$val]
    for key, val in ONode.listProps:
        result &= "\n$1: $2" % [key, $$val]
    result &= " }"

proc children*(n: ONode): seq[ONode] =
    result = @[]
    for ONode in n.nodeProps.values:
        result.add(ONode)
    for list in n.listProps.values:
        result.extend(list)

proc isBranch*(n: ONode): bool =
    return n.children.len > 0

proc isLeaf*(n: ONode): bool =
    return not n.isBranch

# TODO: This whole `equiv` nonsense is smelly

proc sameKeys[K, V](t1: Table[K, V], t2: Table[K, V]): bool =
    # TODO Make less inefficient
    for key in t1.keys:
        if key notin t2:
            return false
    for key in t2.keys:
        if key notin t1:
            return false
    return true

proc equiv*(ONode: ONode, other: ONode): bool

proc equiv[K, V](t1: Table[K, V], t2: Table[K, V]): bool =
    if not sameKeys(t1, t2):
        return false

    for key in t1.keys:
        if not equiv(t1[key], t2[key]):
            return false

    return true

proc equiv(s1: seq[ONode], s2: seq[ONode]): bool =
    if s1.len != s2.len:
        return false

    for i in 0 ..< s1.len:
        if not equiv(s1[i], s2[i]):
            return false

    return true

proc equiv*(ONode: ONode, other: ONode): bool =
    ## Not `==` because `==` is for identity.
    ## NOTE: This does not verifiy that the two ONodes' have matching
    ## return type. This is intentional.
    return ONode of other.type and other of ONode.type and  # Ensure of same type
        ONode.textProps == other.textProps and
        equiv[string, ONode](ONode.nodeProps, other.nodeProps) and
        equiv[string, seq[ONode]](ONode.listProps, other.listProps)

proc descendants*(ONode: ONode): seq[ONode] =
    ## Recursively iterates through all descendants of given ONode.
    result = ONode.children
    var head = 0  # Index of current ONode we're unpacking

    while head < result.len:
        let current_ONode = result[head]
        if current_ONode.isBranch:
            result.extend(current_ONode.children)
        inc(head)

proc layers*(ONode: ONode): seq[seq[ONode]] =
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
    result = @[@[ONode]]
    while true:
        let prevLayer = result[result.len - 1]
        var newLayer: seq[ONode] = @[]

        for ONode in prevLayer:
            newLayer.extend(ONode.children)

        if newLayer.len == 0:
            break
        else:
            result.add(newLayer)

proc ancestors*(ONode: ONode): seq[ONode] =
    result = @[]
    var curONode = ONode.parent
    while not curONode.isNil:
        result.add(curONode)
        curONode = curONode.parent

proc scoped*(ONode: ONode): seq[ONode] =
    # Return all of ONode's descendants, except those contained
    # inside a Lambda contained inside the given ONode.
    result = ONode.children
    var head = 0  # Index of current ONode we're unpacking

    while head < result.len:
        let currentONode = result[head]
        if currentONode.isBranch and not (currentONode of Lambda):
            result.extend(currentONode.children)
        inc(head)
 