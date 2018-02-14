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

let liltParserAst* = Program(p(@[d("line_comment",l(s(@[li("/"),re(li("")),o(op(s(@[g(r("newline")),r("any")])))]))),d("block_comment",l(s(@[li("(("),re(li("")),o(op(s(@[g(li("))")),r("any")]))),li("))")]))),d("comment",c(@[r("line_comment"),r("block_comment")])),d("_",o(op(c(@[r("whitespace"),r("comment")])))),d("_nn",o(op(c(@[s(@[g(r("newline")),r("whitespace")]),r("comment")])))),d("identifier",op(c(@[r("alphanum"),li("_")]))),d("escape_char",li("\\")),d("program",l(s(@[pr("definitions",l(o(op(s(@[r("_"),e(r("definition"))]))))),r("_")]))),d("definition",l(s(@[pr("id",r("identifier")),r("_"),li(":"),r("_"),pr("body",r("body"))]))),d("sequence",l(pr("contents",l(s(@[e(r("expression")),op(s(@[r("_nn"),e(r("expression"))]))]))))),d("choice",l(s(@[o(s(@[li("|"),r("_")])),pr("contents",l(s(@[e(r("choice_term")),op(s(@[r("_"),li("|"),r("_"),e(r("choice_term"))]))]))),o(s(@[r("_"),li("|")]))]))),d("choice_term",c(@[r("sequence"),r("expression")])),d("body",c(@[r("choice"),r("sequence"),r("expression")])),d("reference",l(pr("id",r("identifier")))),d("maybe_escaped_char",c(@[s(@[g(r("escape_char")),r("any")]),s(@[r("escape_char"),se("\\trclabe\'\">")]),s(@[r("escape_char"),li("x"),r("hex_char"),r("hex_char")])])),d("hex_char",c(@[se("abcdefABCDEF"),r("digit")])),d("double_quote_literal",l(s(@[li("\""),a(o(op(r("double_quote_literal_char")))),li("\"")]))),d("double_quote_literal_char",c(@[s(@[r("escape_char"),li("\"")]),s(@[g(li("\"")),r("maybe_escaped_char")])])),d("single_quote_literal",l(s(@[li("\'"),a(o(op(r("single_quote_literal_char")))),li("\'")]))),d("single_quote_literal_char",c(@[s(@[r("escape_char"),li("\'")]),s(@[g(li("\'")),r("maybe_escaped_char")])])),d("literal",l(pr("text",c(@[r("double_quote_literal"),r("single_quote_literal")])))),d("set",l(s(@[li("<"),pr("charset",o(op(r("set_char")))),li(">")]))),d("set_char",c(@[s(@[r("escape_char"),li(">")]),s(@[g(li(">")),r("maybe_escaped_char")])])),d("optional",l(s(@[li("?"),pr("inner",r("expression"))]))),d("oneplus",l(s(@[li("+"),pr("inner",r("expression"))]))),d("zeroplus",l(s(@[li("*"),pr("inner",r("expression"))]))),d("guard",l(s(@[li("!"),pr("inner",r("expression"))]))),d("result",l(s(@[li("#"),pr("inner",r("expression"))]))),d("adjoinment",l(s(@[li("$"),pr("inner",r("expression"))]))),d("property",l(s(@[pr("name",r("identifier")),li("="),pr("inner",r("expression"))]))),d("extension",l(s(@[li("&"),pr("inner",r("expression"))]))),d("brackets",l(s(@[li("["),r("_"),pr("body",r("body")),r("_"),li("]")]))),d("lambda",l(s(@[li("{"),r("_"),pr("body",r("body")),r("_"),li("}")]))),d("expression",c(@[r("property"),r("reference"),r("literal"),r("set"),r("optional"),r("oneplus"),r("zeroplus"),r("guard"),r("result"),r("adjoinment"),r("extension"),r("brackets"),r("lambda")]))]))
