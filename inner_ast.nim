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
from misc import `>$`

type Node* = object
  isLeaf*: bool
  code*: string  # iff isLeaf

  # iff not isLeaf; is branch:
  kind*: string
  nodeProps*: Table[string, Node]  # Properties which map to nodes
  childProps*: Table[string, seq[Node]]  # Properties which map to lists
  codeProps*: Table[string, string]

proc `==`*(node: Node, other: Node): bool =
  if node.isLeaf != other.isLeaf:
    return false

  let areLeaves = node.isLeaf
  if areLeaves:
    return node.code == other.code

  # else are branches
  return node.kind == other.kind and
    node.nodeProps == other.nodeProps and
    node.childProps == other.childProps and
    node.codeProps == other.codeProps

proc `$$`[K, V](t: Table[K, V]): string =
  var parts: seq[string] = @[]
  for key in t.keys:
    parts.add("$1: $2" % [$key, $t[key]])
  return "{\n$1\n}" % >$ parts.join("\n")

proc `$`*(node: Node): string =
  if node.isLeaf:
    return "code leaf: '$1'" % node.code
  else:
    var props = initTable[string, string]()
    props["kind"] = if node.kind.isNil: "\"\"" else: "\"$1\"" % $node.kind
    for key, val in node.nodeProps.pairs:
      props[key] = >$ $val
    for key, val in node.childProps.pairs:
      props[key] = >$ $val
    for key, val in node.codeProps.pairs:
      props[key] = val

    result = "{"
    for key, val in props:
      result &= "\n\t\"$1\": $2," % [key, val]
    result &= "\n}"

proc `$$`*(node: Node): string =
  return $node

template isBranch*(node: Node): bool =
  not node.isLeaf

const
  noNodeProps* = initTable[string, Node]()
  noChildProps* = initTable[string, seq[Node]]()
  noCodeProps* = initTable[string, string]()

proc newCode*(code: string): Node =
  return Node(isLeaf: true, code: code, kind: nil, nodeProps: noNodeProps, childProps: noChildProps, codeProps: noCodeProps)

proc newBranch*(kind: string, nodeProps: Table[string, Node], childProps: Table[string, seq[Node]], codeProps: Table[string, string]): Node =
  return Node(isLeaf: false, code: nil, kind: kind, nodeProps: nodeProps, childProps: childProps, codeProps: codeProps)

proc newBranch*(kind: string, nodeProps: Table[string, Node]): Node =
  return newBranch(kind, nodeProps, noChildProps, noCodeProps)

proc newBranch*(kind: string, childProps: Table[string, seq[Node]]): Node =
  return newBranch(kind, noNodeProps, childProps, noCodeProps)

proc newBranch*(kind: string, codeProps: Table[string, string]): Node =
  return newBranch(kind, noNodeProps, noChildProps, codeProps)