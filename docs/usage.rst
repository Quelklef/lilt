
.. highlight:: nim

Usage
=====

Lilt is on nimble. A simple `nimble refresh` will download or update the package.


Parsing
-------

:code:`import lilt` will only import one thing:

:code:`proc makeParser*(code: string): proc(text: string): Node`

The :code:`Node` type is from the ast import below.

:code:`makeParser` accepts a lilt specification and generates a parser for it. This parser is returned as the form of a proc mapping :code:`text` to a :code:`Node` (an AST).

Ast
---

:code:`import lilt.inner_ast`\* will expose the following:

\* This will eventually be renamed to something less arcane, like "ast"

*The module exposes some extra undocumented procedures which may be used at your own risk.*

Node Type
~~~~~~~~~

The :code:`Node` represents a node on the AST. It contains a *kind*, which is the type of the node, as well as several *properties*.

Its definition looks like::

    Node = object
        kind: string
        properties: TableRef[string, Property]


Property
~~~~~~~~

A *property* represents a single value of a node's property. It can either be text, another node, or a list (seq) of nodes.

The definiton looks like::

    Property* = object
        case kind: LiltType
        of ltText:
            text: string
        of ltNode:
            node: Node
        of ltList:
            list: seq[Node]

Lilt Kind
~~~~~~~~~

Values in Lilt can only be of three types: text, a node, or a list of nodes.

This is implemented as an enumeration::

    type LiltType = enum
      ltText
      ltNode
      ltList


Node Procedures
~~~~~~~~~~~~~~~

Several initializers are included::

    proc initProperty*(text: string): Property
    proc initProperty*(node: Node): Property
    proc initProperty*(list: seq[Node]): Property

    proc initNode*(kind: string): Node
    proc initNode*(kind: string, props: TableRef[string, Property]): Node
    proc initNode*(kind: string, props: openarray[(string, Property)]): Node
    proc initNode*(kind: string, props: openarray[(string, string)]): Node
    proc initNode*(kind: string, props: openarray[(string, Node)]): Node
    proc initNode*(kind: string, props: openarray[(string, seq[Node])]): Node

As well as::

    proc `==`*(node: Node, other: Node): bool
    proc `==`*(prop: Property, other: Property): bool
    proc `$`*(node: Node): string