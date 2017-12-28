
# Lilt

Lilt is a language for defining syntax (grammar? who knows).
Currently, it only allows checks if code follows the given syntax.
It is planned to become a two-in-one syntax definer and parser.

# Rules

A _rule_ is a syntax definition, for instance "exactly matches 'apple'".
It can be thought of as a predicate, or a function that maps strings to booleans.

Rules are how Lilt runs; almost any piece of Lilt code is parsed into a rule.

## Literals

Literals are rules that match the given text _exactly_.

All literals share these escape codes:
`\\`, `\n`, `\t`, `\r`, `\c`, `\l`, `\a`, `\b`, and `\e`.

### Short literals

Short literals are written with a `'` followed by sequence of non-whitespace characters.
The short literal `'banana` matches the text "banana"\*.

`'` may be in a short literal but must be escaped.

### Long literals
Long literals are like short literals but begin and end with a `"` and can contain any character.

`"` may be in a long literal but must be escaped.

## Set Expressions

Set expressions begin and end with a `<` and `>` and match any single character contained in them.

For instance, `<abcd>` matches `a`, `b`, `c`, and `d`.

Set expressions share the literal escape codes; additionally,
`<` and `>` may be in set expressions but must be escaped.

## Question Expression

Question expressions begin with a `?`. They optionally match the inside expression.

For instance, `?"banana"` matches `banana` and `not banana`.

This seems useless, but is not, since it doesn't _consume_ code it doesn't match.

## Star Expressions

Star expressions begin with a `*` and match 0 or more of the inside expression.

For instance,`*<abc>` matches `aaa`, `abb`, `acccb`, etc.

## Plus Expressions

Plus expressions begin with a `+` and match 1 or more of the inside expression.

## Brackets

Brackets begin and end with `[` and `]` and are analogous to parenthesis in other languages.

## Sequences

If rules are in sequence, they will match text that follows that order.

For instance, `"banana phone" <!.>` matches only `banana phone.` and `banana phone!`

## Option sequences

If rules are separated by pipes (`|`), they will match text that matches _any_ contained rule.

So, `"banana" | "phone"` matches both `banana` and `phone`.
