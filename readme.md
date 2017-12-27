
# Lilt

Lilt is currently a pseudo-parser.
It checks if some text matches a certain specification.
Eventually, it is supposed to become a combined lexer and parser.

Because I find explaining things to be difficult, I will instead provide an example
implementation of a JSON parser in Lilt.

```
ws: < > | <
>

object: '{ *ws *members *ws '}
members: string *ws ': *ws value ?[*ws ', *ws members]

array: '[ *ws *values *ws ']
values: value ?[*ws ', *ws values]

value: string | number | object | array | 'true | 'false | 'null

string: '" *strChar '"
strChar: <abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 >

nonZero: <123456789>
digit: <1234567890>
number: ?'- ['0 | [nonZero *digit]] ?['. +digit] ?[['e | 'E ] ?['+ | '- ] +digit]

prog: *ws array *ws
```

\*It is missing a few things due to the current incompleteness of Lilt.
