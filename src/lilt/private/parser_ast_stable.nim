import outer_ast

type N = ONode
template p (a: seq[N]): N = newProgram(a)
template r (a: string): N = newReference(a)
template d (a: string, b: N): N = newDefinition(a, b)
template l (a: N): N = newLambda(a)
template s (a: seq[N]): N = newSequence(a)
template c (a: seq[N]): N = newChoice(a)
template li(a: string): N = newLiteral(a)
template se(a: string): N = newSet(a)
template o (a: N): N = newOptional(a)
template op(a: N): N = newOnePlus(a)
template g (a: N): N = newGuard(a)
template re(a: N): N = newResult(a)
template a (a: N): N = newAdjoinment(a)
template e (a: N): N = newExtension(a)
template pr(a: string, b: N): N = newProperty(a, b)

let liltParserAst* = Program(p(@[d("line_comment",l(s(@[li("/").N,re(li("")),o(op(s(@[g(r("newline")).N,r("any")])))]))).N,d("block_comment",l(s(@[li("((").N,re(li("")),o(op(s(@[g(li("))")).N,r("any")]))),li("))")]))),d("comment",c(@[r("line_comment").N,r("block_comment")])),d("d",o(op(c(@[r("whitespace").N,r("comment")])))),d("md",o(op(c(@[s(@[g(r("newline")).N,r("whitespace")]).N,r("comment")])))),d("identifier",op(c(@[r("alphanum").N,li("_")]))),d("escape_char",li("\\")),d("program",l(s(@[pr("definitions",l(o(op(s(@[r("d").N,e(r("definition"))]))))).N,r("d")]))),d("definition",l(s(@[pr("id",r("identifier")).N,r("d"),li(":"),r("d"),pr("body",r("body"))]))),d("sequence",l(pr("contents",l(s(@[e(r("expression")).N,op(s(@[r("md").N,e(r("expression"))]))]))))),d("choice",l(s(@[o(s(@[li("|").N,r("d")])).N,pr("contents",l(s(@[e(r("expression")).N,op(s(@[r("d").N,li("|"),r("d"),e(r("expression"))]))]))),o(s(@[r("d").N,li("|")]))]))),d("body",c(@[r("sequence").N,r("choice"),r("expression")])),d("reference",l(pr("id",r("identifier")))),d("maybe_escaped_char",c(@[s(@[g(r("escape_char")).N,r("any")]).N,s(@[r("escape_char").N,se("\\trclabe")])])),d("double_quote_literal",l(s(@[li("\"").N,a(o(op(r("double_quote_literal_char")))),li("\"")]))),d("double_quote_literal_char",c(@[s(@[r("escape_char").N,li("\"")]).N,s(@[g(li("\"")).N,r("maybe_escaped_char")])])),d("single_quote_literal",l(s(@[li("\'").N,a(o(op(r("single_quote_literal_char")))),li("\'")]))),d("single_quote_literal_char",c(@[s(@[r("escape_char").N,li("\'")]).N,s(@[g(li("\'")).N,r("maybe_escaped_char")])])),d("literal",l(pr("text",c(@[r("double_quote_literal").N,r("single_quote_literal")])))),d("set",l(s(@[li("<").N,pr("charset",o(op(r("set_char")))),li(">")]))),d("set_char",c(@[s(@[r("escape_char").N,li(">")]).N,s(@[g(li(">")).N,r("maybe_escaped_char")])])),d("optional",l(s(@[li("?").N,pr("inner",r("expression"))]))),d("oneplus",l(s(@[li("+").N,pr("inner",r("expression"))]))),d("zeroplus",l(s(@[li("*").N,pr("inner",r("expression"))]))),d("guard",l(s(@[li("!").N,pr("inner",r("expression"))]))),d("result",l(s(@[li("#").N,pr("inner",r("expression"))]))),d("adjoinment",l(s(@[li("$").N,pr("inner",r("expression"))]))),d("property",l(s(@[pr("name",r("identifier")).N,li("="),pr("inner",r("expression"))]))),d("extension",l(s(@[li("&").N,pr("inner",r("expression"))]))),d("brackets",l(s(@[li("[").N,r("d"),pr("body",r("body")),r("d"),li("]")]))),d("lambda",l(s(@[li("{").N,r("d"),pr("body",r("body")),r("d"),li("}")]))),d("expression",c(@[r("property").N,r("reference"),r("literal"),r("set"),r("optional"),r("oneplus"),r("zeroplus"),r("guard"),r("result"),r("adjoinment"),r("extension"),r("brackets"),r("lambda")]))]))
