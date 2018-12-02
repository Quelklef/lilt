
.. highlight:: nim

Usage
=====

Lilt is on nimble. A simple :code:`nimble refresh` will download or update the package. Then, in your Nim code, just :code:`import lilt`.

We'll start with the bread and butter parser type::

    Parser* = proc(text: string): LiltValue

A parser accepts some text and returns a parsed *value*. Alternatively, it may throw a :code:`RuleError`, which just says that the text didn't match the parser.

The returned value may be text, a node, or a list of nodes. This is encoded in the next three types::

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

    Node* = object
        kind*: string  # name of the rule that this node was parsed by
        properties*: TableRef[string, LiltValue]  # properties of the node

Instead of writing :code:`node.properties[key]`, one can just write :code:`node[key]` via the following proc::

    proc `[]`(node: Node, key: string): LiltValue =
      return node.properties[key]

In order to create parsers, one should use the included :code:`makeParsers` proc, which looks like::

    proc makeParsers*(code: string): Table[string, Parser]

It accepts a Lilt specification (:code:`code`), and returns all of the defined rules in that specification as a table mapping :code:`string`s to :code:`Parser`s.

For your convenience, three :code:`LiltValue` initializers have also been included::

    proc initLiltValue*(text: string): LiltValue =
        return LiltValue(kind: ltText, text: text)

    proc initLiltValue*(node: Node): LiltValue =
        return LiltValue(kind: ltNode, node: node)

    proc initLiltValue*(list: seq[Node]): LiltValue =
        return LiltValue(kind: ltList, list: list)

Example
-------

We'll use the JSON parser example from the tutorial::

    import lilt
    import tables

    # Create our Lilt specification
    # Could also be, for instance, read from a file
    const spec = """
    value: _ #[string | number | object | array | trueLiteral | falseLiteral | nullLiteral] _
    trueLiteral: _="" "true"
    falseLiteral: _="" "false"
    nullLiteral: _="" "null"

    string: '"' value=*stringChar '"'
    stringChar: [!<"\\> any] | "\\" [</\\bfnrt> | "u" hexDig hexDig hexDig hexDig]
    hexDig: <1234567890ABCDEFabcdef>

    number: ?negative="-" wholes=["0" | +digit] ?["." decimals=*digit] ?exponent=numberExp
    numberExp: <eE> sign=<+-> digits=+digit

    object: "{" _ pairs=?{&pair *["," &pair]} _ "}"
    pair: _ key=string _ ":" _ value=value _

    array: "[" _ items=?{&value *["," &value]} _ "]"
    """

    # Is a Table[string, Parser]
    let parsers = makeParsers(spec)

    # Let's say we want to parse a number
    # Get that parser by the name of the rule: "number"
    let numberParser = parsers["number"]

    # ...and use it!
    let parsedNumber = numberParser("3.0e+10")

    echo parsedNumber.node["wholes"].text  # "3"
    echo parsedNumber.node["decimals"].text  # "0"
    echo parsedNumber.node["exponent"].node["sign"].text  # "+"
    echo parsedNumber.node["exponent"].node["digits"].text  # "10"


    # Let's try it with some simple JSON
    let jsonParser = parsers["value"]

    echo jsonParser("30").node  # {"wholes": "30"}
    echo jsonParser("\"string\"").node  # {"value": "string"}
    echo jsonParser("""
    {
      "name": "marbles",
      "color": "red",
      "count": 100
    }
    """).node
    #[ becomes
    {
      "pairs": [
        {
          "key": {"value": "name"},
          "value": {"value": "marbles"}
        },
        {
          "key": {"value": "color"},
          "value": {"value": "red"}
        },
        {
          "key": {"value": "count"},
          "value": {"wholes": 100},
        }
      ]
    }
    ]#

Sublime Text 3 Integration
--------------------------

:file:`st3/Lilt.sublime-syntax` contains a syntax definition for Lilt specifications usable with Sublime Text 3. Unfortuantely, there is no package on Package Control (yet).

To install, just drop :file:`Lilt.sublime-text` into :file:`~/.config/sublime-text-3/Packages/User`. Then, in ST3, select `view > syntax > Lilt`. However, this should not be needed for :file:`.lilt` files.
