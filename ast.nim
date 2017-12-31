
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

]#

#[
Note that everything is a "ref object of" rather than an "object of"
This is because it's needed for the polymorphism to work
for some reason...
]#


import sequtils
import strutils

proc `>$`(s: string, indentText = "\t"): string =
    ## Ident a block of text
    return s.split("\n").mapIt(indentText & it).join("\n")

type Node* = ref object of RootObj

method `$`*(n: Node): string {.base.} =
    # For some reason this base method needs to be implemented
    # for the non-base methods to work properly
    return "[NODE]"

method `$$`*(n: Node): string {.base.} =
    return "NODE (seeing this is bad!)"

# Program

type Program* = ref object of Node
    definitions*: seq[Node]

proc newProgram*(dfns: seq[Node]): Program =
    return Program(definitions: dfns)

method `$`*(p: Program): string =
    var st = ""
    for def in p.definitions:
        st &= " " & $def
    return "[PROGRAM$1]" % st

method `$$`*(p: Program): string =
    var inners: seq[string] = @[]
    for def in p.definitions:
        inners.add($$def)
    return "PROGRAM\n$1" % >$ inners.join("\n")

# Reference

type Reference* = ref object of Node
    id*: string

proc newReference*(id: string): Reference =
    return Reference(id: id)

method `$`*(r: Reference): string =
    return "[REF '$1']" % r.id

method `$$`*(r: Reference): string =
    return "REFERENCE '$1'" % r.id

# Definition

type Definition* = ref object of Node
    id*: string
    body*: Node

proc newDefinition*(id: string, body: Node): Definition =
    return Definition(id: id, body: body)

method `$`*(d: Definition): string =
    return "[DEF '$1' $2]" % [$d.id, $d.body]

method `$$`*(d: Definition): string =
    return "DEFINITION '$1'\n$2" % [$d.id, >$ $$d.body]

# Sequence

type Sequence* = ref object of Node
    contents*: seq[Node]

proc newSequence*(cts: seq[Node]): Sequence =
    return Sequence(contents: cts)

method `$`*(s: Sequence): string =
    var st = ""
    for n in s.contents:
        st &= " " & $n
    return "<SEQ$1>" % st

method `$$`*(s: Sequence): string =
    var inners: seq[string] = @[]
    for n in s.contents:
        inners.add($$n)
    return "SEQUENCE\n$1" % >$ inners.join("\n")

# Choice

type Choice* = ref object of Node
    contents*: seq[Node]

proc newChoice*(cts: seq[Node]): Choice =
    return Choice(contents: cts)

method `$`*(c: Choice): string =
    var st = ""
    for n in c.contents:
        st &= " " & $n
    return "<CHOICE$1>" % st

method `$$`(c: Choice): string =
    var inners: seq[string] = @[]
    for n in c.contents:
        inners.add($$n)
    return "CHOICE\n$1" % >$ inners.join("\n")

# Literal

type Literal* = ref object of Node
    text*: string

proc newLiteral*(text: string): Literal =
    return Literal(text: text)

method `$`*(li: Literal): string =
    return "[LIT '$1']" % li.text

method `$$`*(li: Literal): string =
    return "LITERAL '$1'" % li.text

# Set

type Set* = ref object of Node
    charset*: string

proc newSet*(charset: string): Set =
    return Set(charset: charset)

method `$`*(s: Set): string =
    return "[SET '$1']" % s.charset

method `$$`*(s: Set): string =
    return "SET '$1'" % s.charset

# Optional

type Optional* = ref object of Node
    inner*: Node

proc newOptional*(inner: Node): Optional =
    return Optional(inner: inner)

method `$`*(o: Optional): string =
    return "[OPTIONAL $1]" % $o.inner

method `$$`*(o: Optional): string =
    return "OPTIONAL\n$1" % >$ $$o.inner

# OnePlus

type OnePlus* = ref object of Node
    inner*: Node

proc newOnePlus*(inner: Node): OnePlus =
    return OnePlus(inner: inner)

method `$`*(op: OnePlus): string =
    return "[ONEPLUS $1]" % $op.inner

method `$$`*(op: OnePlus): string =
    return "ONEPLUS\n$1" % >$ $$op.inner

# Guard

type Guard* = ref object of Node
    inner*: Node

proc newGuard*(inner: Node): Guard =
    return Guard(inner: inner)

method `$`*(g: Guard): string =
    return "[GUARD $1]" % $g.inner

method `$$`*(g: Guard): string =
    return "GUARD\n$1" % >$ $$g.inner
    
