#[ 
AST definiton for parsed Lilt code.
]#

#[
Each kind of node on the AST, e.g. ADD_OP, FUNC_DEF, etc.
has its own type.

They should all inherit from Node and should
fulfill the following contract:

method `$`*: string
    String representation of the node

method `$$`*: string
    Pretty string representation of the node,
    i.e. with indentation and stuff

method children: seq[Node]
    return all children of the node
    if no children, return @[]

Note that everything is a "ref object of" rather than an "object of"
This is because it's needed for the polymorphism to work
for some reason...
]#


import sequtils
import strutils
from misc import BaseError, `>$`

type RuleReturnType* = enum
    rrtUnknown
    rrtTypeless

    rrtCode
    rrtNode
    rrtList

type Node* = ref object of RootObj
    returnType*: RuleReturnType
    parent*: Node

method `$`*(n: Node): string {.base, noSideEffect.} =
    # For some reason this base method needs to be implemented
    # for the non-base methods to work properly
    raise newException(BaseError, "")

method `$$`*(n: Node): string {.base.} =
    raise newException(BaseError, "")

method children*(n: Node): seq[Node] {.base.} =
    raise newException(BaseError, "")

proc isBranch*(n: Node): bool =
    return n.children.len > 0

proc isLeaf*(n: Node): bool =
    return not n.isBranch

method `==`*(node: Node, other: Node): bool {.base, noSideEffect.} =
    raise newException(BaseError, "Cannot use `==` with base type Node. Given: $1" % $node)

template extend[T](s1: seq[T], s2: seq[T]) =
  for item in s2:
    s1.add(item)

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

method `$`*(p: Program): string =
    var st = ""
    for def in p.definitions:
        st &= " " & $def
    return "[PROGRAM$1]" % st

method `$$`*(p: Program): string =
    var inners: seq[string] = @[]
    for def in p.definitions:
        inners.add($$def)
    return "$1 PROGRAM\n$2" % [$p.returnType, >$ inners.join("\n")]

method children*(p: Program): seq[Node] =
    return p.definitions

method `==`*(prog: Program, other: Node): bool =
    return other of Program and prog.definitions == other.Program.definitions

# Reference

type Reference* = ref object of Node
    id*: string

proc newReference*(id: string): Reference =
    return Reference(id: id)

method `$`*(r: Reference): string =
    return "[REF '$1']" % r.id

method `$$`*(r: Reference): string =
    return "$1 REFERENCE '$2'" % [$r.returnType, r.id]

method children*(r: Reference): seq[Node] =
    return @[]

method `==`*(r: Reference, other: Node): bool =
    return other of Reference and r.id == other.Reference.id

# Definition

type Definition* = ref object of Node
    id*: string
    body*: Node

proc newDefinition*(id: string, body: Node): Definition =
    let d = Definition(id: id, body: body)
    body.parent = d
    return d

method `$`*(d: Definition): string =
    return "[DEF '$1' $2]" % [$d.id, $d.body]

method `$$`*(d: Definition): string =
    return "$1 DEFINITION '$2'\n$3" % [$d.returnType, $d.id, >$ $$d.body]

method children*(d: Definition): seq[Node] =
    return @[d.body]

method `==`*(def: Definition, other: Node): bool =
    if not (other of Definition):
        return false

    let otherDef = Definition(other)
    return def.id == otherDef.id and
        def.body == otherDef.body

# Sequence

type Sequence* = ref object of Node
    contents*: seq[Node]

proc newSequence*(cts: seq[Node]): Sequence =
    let s = Sequence(contents: cts)
    for node in s.contents:
        node.parent = s
    return s

method `$`*(s: Sequence): string =
    var st = ""
    for n in s.contents:
        st &= " " & $n
    return "<SEQ$1>" % st

method `$$`*(s: Sequence): string =
    var inners: seq[string] = @[]
    for n in s.contents:
        inners.add($$n)
    return "$1 SEQUENCE\n$2" % [$s.returnType, >$ inners.join("\n")]

method children*(s: Sequence): seq[Node] =
    return s.contents

method `==`*(se: Sequence, other: Node): bool =
    return other of Sequence and se.contents == other.Sequence.contents

# Choice

type Choice* = ref object of Node
    contents*: seq[Node]

proc newChoice*(cts: seq[Node]): Choice =
    let c = Choice(contents: cts)
    for node in cts:
        node.parent = c
    return c

method `$`*(c: Choice): string =
    var st = ""
    for n in c.contents:
        st &= " " & $n
    return "<CHOICE$1>" % st

method `$$`(c: Choice): string =
    var inners: seq[string] = @[]
    for n in c.contents:
        inners.add($$n)
    return "$1 CHOICE\n$2" % [$c.returnType, >$ inners.join("\n")]

method children*(c: Choice): seq[Node] =
    return c.contents

method `==`*(choice: Choice, other: Node): bool =
    return other of Choice and choice.contents == other.Choice.contents

# Literal

type Literal* = ref object of Node
    text*: string

proc newLiteral*(text: string): Literal =
    return Literal(text: text)

method `$`*(li: Literal): string =
    return "[LIT '$1']" % li.text

method `$$`*(li: Literal): string =
    return "$1 LITERAL '$2'" % [$li.returnType, li.text]

method children*(li: Literal): seq[Node] =
    return @[]

method `==`*(li: Literal, other: Node): bool =
    return other of Literal and li.text == other.Literal.text

# Set

type Set* = ref object of Node
    charset*: string

proc newSet*(charset: string): Set =
    return Set(charset: charset)

method `$`*(s: Set): string =
    return "[SET '$1']" % s.charset

method `$$`*(s: Set): string =
    return "$1 SET '$2'" % [$s.returnType, s.charset]

method children*(s: Set): seq[Node] =
    return @[]

method `==`*(se: Set, other: Node): bool =
    return other of Set and se.charset == other.Set.charset

# Optional

type Optional* = ref object of Node
    inner*: Node

proc newOptional*(inner: Node): Optional =
    let o = Optional(inner: inner)
    inner.parent = o
    return o

method `$`*(o: Optional): string =
    return "[OPTIONAL $1]" % $o.inner

method `$$`*(o: Optional): string =
    return "$1 OPTIONAL\n$2" % [$o.returnType, >$ $$o.inner]

method children*(o: Optional): seq[Node] =
    return @[o.inner]

method `==`*(opt: Optional, other: Node): bool =
    return other of Optional and opt.inner == other.Optional.inner

# OnePlus

type OnePlus* = ref object of Node
    inner*: Node

proc newOnePlus*(inner: Node): OnePlus =
    let op = OnePlus(inner: inner)
    inner.parent = op
    return op

method `$`*(op: OnePlus): string =
    return "[ONEPLUS $1]" % $op.inner

method `$$`*(op: OnePlus): string =
    return "$1 ONEPLUS\n$2" % [$op.returnType, >$ $$op.inner]

method children(op: OnePlus): seq[Node] =
    return @[op.inner]

method `==`*(op: OnePlus, other: Node): bool =
    return other of OnePlus and op.inner == other.OnePlus.inner

# Guard

type Guard* = ref object of Node
    inner*: Node

proc newGuard*(inner: Node): Guard =
    let g = Guard(inner: inner)
    inner.parent = g
    return g

method `$`*(g: Guard): string =
    return "[GUARD $1]" % $g.inner

method `$$`*(g: Guard): string =
    return "$1 GUARD\n$2" % [$g.returnType, >$ $$g.inner]

method children*(g: Guard): seq[Node] =
    return @[g.inner]

method `==`*(guard: Guard, other: Node): bool =
    return other of Guard and guard.inner == other.Guard.inner

# Extension

type Extension* = ref object of Node
    inner*: Node

proc newExtension*(inner: Node): Extension =
    let e = Extension(inner: inner)
    inner.parent = e
    return e

method `$`*(e: Extension): string =
    return "[EXT $1]" % $e.inner

method `$$`*(e: Extension): string =
    return "$1 EXTENSION\n$2" % [$e.returnType, >$ $$e.inner]

method children*(e: Extension): seq[Node] =
    return @[e.inner]

method `==`*(ext: Extension, other: Node): bool =
    return other of Extension and ext.inner == other.Extension.inner

# Property

type Property* = ref object of Node
    propName*: string
    inner*: Node

proc newProperty*(name: string, inner: Node): Property =
    let p = Property(propName: name, inner: inner)
    inner.parent = p
    return p

method `$`*(p: Property): string =
    return "[PROP '$1' $2]" % [p.propName, $p.inner]

method `$$`*(p: Property): string =
    return "$1 PROPERTY '$2'\n$3" % [$p.returnType, p.propName, >$ $$p.inner]

method children*(p: Property): seq[Node] =
    return @[p.inner]

method `==`*(prop: Property, other: Node): bool =
    if not (other of Property):
        return false

    let otherProp = Property(other)
    return otherProp.propName == prop.propName and
        otherProp.inner == prop.inner
