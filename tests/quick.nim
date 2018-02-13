
#[
Implements a bunch of templates and macros for nicely making an outer ast
]#

import lilt/private/outer_ast

template `:=`*(id: string, body: ONode): ONode = newDefinition(id, body)
template `%=`*(id: string, body: ONode): ONode = newDefinition(id, newLambda(body))

template `%`*(body: ONode): ONode = newLambda(body)

template `~`*(contents: openarray[ONode]): ONode = newSequence(@contents)
template `|`*(contents: openarray[ONode]): ONode = newChoice(@contents)

template `<>`*(code: string): ONode = newSet(code)
template `@`*(id: string): ONode = newReference(id)
template `^`*(code: string): ONode = newLiteral(code)

template `+`*(inner: ONode): ONode = newOneplus(inner)
template `?`*(inner: ONode): ONode = newOptional(inner)
template `*`*(inner: ONode): ONode = newOptional(newOneplus(inner))
template `!`*(inner: ONode): ONode = newGuard(inner)

# The hash is used in Nim for comments, so the arbitrary "/." is chosen
template `/.`*(inner: ONode): ONode = newResult(inner)
# Not `$` as to not conflict with `$` conventions
template `$:`*(inner: ONode): ONode = newAdjoinment(inner)
template `.=`*(id: string, inner: ONode): ONode = newProperty(id, inner)
template `&`*(inner: ONode): ONode = newExtension(inner)
