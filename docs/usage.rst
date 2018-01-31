
.. highlight:: nim

Usage
=====

Lilt is on nimble. A simple `nimble refresh` will download or update the package. Then, in your Nim code, just `import lilt`.

Lilt defines a since procedure and 4 types.

Firstly, the bread and butter, the parser type::

    Parser* = proc(text: string): LiltValue

A parser accepts some text and returns a parsed *value*. Alternatively, it may throw a `RuleError`, which just says that the text didn't match the parser.

The returned value may be text, a node, or a list of nodes. This is encoded in the next two types::

    LiltType* = enum
        ltText
        ltNode
        ltList

    LiltValue* = object
        case kind*: LiltType
        of ltText:
            text*: string
        of ltNode:
            node*: Node
        of ltList:
            list*: seq[Node]

In order to create parsers, one should use the included `makeParsers` proc, which looks like::

    proc makeParsers*(code: string, consumeAll=true): Table[string, Parser]

It accepts a Lilt specification (`code`), and returns all of the defined rules in that specification as a table mapping `string`s to `Parser`s.
