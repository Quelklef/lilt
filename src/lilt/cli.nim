
#[
Defines a command-line interface for Lilt.
]#

import strutils
import docopt
import json

import ../lilt

let doc = """
Lilt

Usage:
  lilt (-h | --help)
  lilt <liltfile> <inputfile> -f=<format> [-p | --pretty]

Options:
  -h --help    Show this screen
  -f=<format>  Sets output type. Accepted values: [json]
  -p --pretty  Output with pretty formatting
"""

let args = docopt(doc)

if args["--help"]:
  echo doc
  quit()

var liltfile = $args["<liltfile>"]
# Allow excluding .lilt extension
if "." notin liltfile:
  liltfile &= ".lilt"

let
    code = $readFile(liltfile)
    text = $readFile($args["<inputfile>"])

    parser = makeParser(code)
    node = parser(text)

let
    format = $args["-f"]
    pretty = args["--pretty"]

var result: string

if format == "=json":
    if pretty:
        result = node.toJson.pretty
    else:
       result = $node.toJson
else:
    echo "Unsupported format '$1'" % format
    quit()

echo result
