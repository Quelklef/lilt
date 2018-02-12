
.. highlight:: nim

Usage
=====

Lilt is on nimble. A simple :code:`nimble refresh` will download or update the package. Then, in your Nim code, just :code:`import lilt`.

We'll start with the bread and butter parser type::

    Parser* = proc(text: string): LiltValue

A parser accepts some text and returns a parsed *value*. Alternatively, it may throw a :code:`RuleError`, which just says that the text didn't match the parser.

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

    proc makeParsers*(code: string): Table[string, Parser]

It accepts a Lilt specification (:code:`code`), and returns all of the defined rules in that specification as a table mapping `string`s to `Parser`s.

For your convenience, three :code:`LiltValue` initializers have also been included::

    proc initLiltValue*(text: string): LiltValue =
        return LiltValue(kind: ltText, text: text)

    proc initLiltValue*(node: Node): LiltValue =
        return LiltValue(kind: ltNode, node: node)

    proc initLiltValue*(list: seq[Node]): LiltValue =
        return LiltValue(kind: ltList, list: list)

Sublime Text 3 Integration
==========================

:file:`st3/Lilt.sublime-syntax` contains a syntax definition for Lilt specifications usable with Sublime Text 3. Unfortuantely, there is no package on Package Control (yet).

To install, just drop :file:`Lilt.sublime-text` into :file:`~/.config/sublime-text-3/Packages/User`. Then, in ST3, select `view > syntax > Lilt`. However, this should not be needed for :file:`.lilt` files.

To be honest, this probably isn't the best way to do it. but it will work/
