#[
The Lilt grammar and parser is written in Lilt.
The processed used to allow for this is somewhat comparable to compiler bootstrapping.

We started with a parser written, in Nim, as a literal Lilt AST.
This could be used as a parser via the Lilt interpreter.
When we write a new Lilt specification (lilt.lilt), it is parsed via the existing parser,
and the resultant AST is so called backwards-processed into Nim code which will generate it.

parser_ast_stable.nim: The stable "previous" version of the parser
parser_ast.nim: The current working parser.
bootstrap.nim: Compile the next parser using parser_ast.nim; output to parser_ast.nim
]#

# Template for output Nim code
const templt = """
import outer_ast

# `.N` to account for Nim type weirdness
# Each array will be assumed to have the type of the first element
# rather than the most general applicable type

type N = ONode
template p (a: seq[N]): N = newProgram(a).N
template r (a: string): N = newReference(a).N
template d (a: string, b: N): N = newDefinition(a, b).N
template l (a: N): N = newLambda(a).N
template s (a: seq[N]): N = newSequence(a).N
template c (a: seq[N]): N = newChoice(a).N
template li(a: string): N = newLiteral(a).N
template se(a: string): N = newSet(a).N
template o (a: N): N = newOptional(a).N
template op(a: N): N = newOnePlus(a).N
template g (a: N): N = newGuard(a).N
template re(a: N): N = newResult(a).N
template a (a: N): N = newAdjoinment(a).N
template e (a: N): N = newExtension(a).N
template pr(a: string, b: N): N = newProperty(a, b).N

let liltParserAst* = Program($1)
"""

import strutils

import misc
import outer_ast
import base

method toNim(n: ONode): string {.base.} =
    ## Converts a node back into Nim code constructing its AST
    raise new(BaseError)

method toNim(p: Program): string =
    var definitions: seq[string] = @[]
    for def in p.definitions:
        definitions.add(def.toNim)
    return "p(@[$1])" % definitions.join(",")

method toNim(r: Reference): string =
    return "r(\"$1\")" % r.id

method toNim(d: Definition): string =
    return "d(\"$1\",$2)" % [d.id, d.body.toNim]

method toNim(l: Lambda): string =
    return "l($1)" % l.body.toNim

method toNim(s: Sequence): string =
    var contents: seq[string] = @[]
    for node in s.contents:
        contents.add(node.toNim)
    return "s(@[$1])" % contents.join(",")

method toNim(c: Choice): string =
    var contents: seq[string] = @[]
    for node in c.contents:
        contents.add(node.toNim)
    return "c(@[$1])" % contents.join(",")

method toNim(li: Literal): string =
    return "li($1)" % liltEscape(li.text)

method toNim(s: Set): string =
    return "se($1)" % liltEscape(s.charset)

method toNim(o: Optional): string =
    return "o($1)" % o.inner.toNim

method toNim(op: OnePlus): string =
    return "op($1)" % op.inner.toNim

method toNim(g: Guard): string =
    return "g($1)" % g.inner.toNim

method toNim(res: Result): string =
    return "re($1)" % res.inner.toNim

method toNim(adj: Adjoinment): string =
    return "a($1)" % adj.inner.toNim

method toNim(ext: Extension): string =
    return "e($1)" % ext.inner.toNim

method toNim(p: Property): string =
    return "pr(\"$1\",$2)" % [p.propName, p.inner.toNim]

#~#

import parse

const spec = slurp("lilt.lilt")
const outFile = "parser_ast.nim"

let ast = parseProgram(spec)
writeFile(outFile, templt % toNim(ast))
