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

type Node* = object
  isLeaf*: bool
  code*: string  # iff isLeaf

  # iff not isLeaf; is branch:
  kind*: string
  nodeProps*: Table[string, Node]  # Properties which map to nodes
  childProps*: Table[string, seq[Node]]  # Properties which map to lists
  codeProps: Table[string, string]

proc `$`*(node: Node): string =
  if node.isLeaf:
    return "[Leaf: '$1']" % node.code
  else:
    return "[Branch: '$1' $2 $3 $4]" % [$node.kind, $node.nodeProps, $node.childProps, $node.codeProps]

template isBranch*(node: Node): bool =
  not node.isLeaf

const
  noNodeProps = initTable[string, Node]()
  noChildProps = initTable[string, seq[Node]]()
  noCodeProps = initTable[string, string]()

proc newCode*(code: string): Node =
  return Node(isLeaf: true, code: code, kind: nil, nodeProps: noNodeProps, childProps: noChildProps, codeProps: noCodeProps)

proc newBranch*(kind: string, props: Table[string, Node], childProps: Table[string, seq[Node]], codeProps: Table[string, string]): Node =
  return Node(isLeaf: false, code: nil, kind: kind, nodeProps: props, childProps: childProps, codeProps: codeProps)
