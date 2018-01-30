
#[
Implements a bunch of templates and macros for writing inline Lilt code
]#

import outer_ast

template `:=`*(id: string, body: Node): Node = newDefinition(id, newLambda(body))

template `%`*(body: Node): Node = newLambda(body)

template `~`*(contents: openarray[Node]): Node = newSequence(@contents)
template `|`*(contents: openarray[Node]): Node = newChoice(@contents)

template `<>`*(code: string): Node = newSet(code)
template `@`*(id: string): Node = newReference(id)
template `^`*(code: string): Node = newLiteral(code)

template `+`*(inner: Node): Node = newOneplus(inner)
template `?`*(inner: Node): Node = newOptional(inner)
template `*`*(inner: Node): Node = newOptional(newOneplus(inner))
template `!`*(inner: Node): Node = newGuard(inner)

# Not `$` as to not conflict with `$` conventions
template `$:`*(inner: Node): Node = newAdjoinment(inner)
template `.=`*(id: string, inner: Node): Node = newProperty(id, inner)
template `&`*(inner: Node): Node = newExtension(inner)
