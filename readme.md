
## Lilt

Lilt is a language for writing parsers.

Lilt, in fact, stands for:

L - Super

I - Duper

L - Easy

T - Parsing

Before explaining what Lilt is and how it works, some disambiguation should be done.
Lilt is a language, and is therefore written in code. This code is parsed and interpreted.
Lilt code, when interpreted, acts as a parser for other, non-Lilt code.

Notice how when talking about Lilt code, one has to consider two different pieces of code
and two different parsers: Lilt code, non-Lilt code, a Lilt parser, and a non-Lilt parser.

In order to mitigate confusion, I will adapt the following convention for this readme:

1. Lilt code will be called "code".
2. Non-Lilt code will be called "text".
3. The parser which parses Lilt code will be called the "parser".
4. The parser which parses non-Lilt code will be called the "AST generator" or just "generator".
5. The Lilt AST will be called the "AST",
6. The Non-Lilt AST will be called the "generated tree" or "Tree".

As such, a piece of Lilt code is run through a parser and interpreted as a generator which acts on text.

***

The fundamental idea of Lilt is a _rule_. A Rule can be though of as a function of text.
A rule is given some text, and does a few things:

- The rule consumes part of the text
- The rule returns one of:
	- A Node on the generated tree,
	- A piece of text (referred to as Code in the source),
	- A List of Nodes.
- The rule may instead _fail_, consuming no text and returning nothing.

A rule may be, for instance, "consume the text 'banana' exactly and return it".
In Lilt, this is written as `"banana"`. Let's call this rule B.

When given the text "sajdjdsk", B will fail, since "sajdjdsk" doesn't match the text "banana".

When given the text "bananas and other fruit", B will consume "banana", leavning "s and other fruit".
Having consumed this text, B will return it; B will return "banana".

Notice how B follows the outline. It consumes part of the text and returns a piece of text, or fails.

Returning Nodes is slightly more complicated.
Let's write a rule for consuming and returning a Node parameter (i.e. of a function):

```
identifier: *<abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUCWXYZ_>
param: id=identifier
```

`<abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUCWXYZ_>` means any of "a", "b", "c", "d", etc.; `*` means zero-or-more.

The `=` syntax is for defining properties. Nodes returned by `param` will have a property
named `id` which is their identifier.

`param` fed "testParam" would return the node:

```JSON
{
	"kind": "param",
	"id": "testParam"
}
```

Using this definiton of `param`, we may want a _list_ of parameters, for instance for
a function definition.

```
paramList: ?&param *[", " &param]
```

The `?` syntax means _optionally_. The `&` syntax means _append_.

So, this rule will try to append one `param`, then append zero or more `param`s, separated by ", ".

`paramList` applied to `param1, param2, param3` would return the node list:

```JSON
[
	{
		"kind": "param",
		"id": "param1"
	},
	{
		"kind": "param",
		"id": "param2"
	},
	{
		"kind": "param",
		"id": "param3"
	}
]
```

Using these two rules, we can finally define a function declaration.

We'll want a function declaration to have a name and list of arguments (but no types). We can do that via:

```
funcDeclaration: "func " id=identifier "(" params=paramList ");"
```

`funcDeclaration` applied to "func multiply(a, b, c);" would return the node:

```JSON
{
	"kind": "funcDeclaration",
	"id": "multiply",
	"params": [
		{
			"kind": "param",
			"id": "a"
		},
		{
			"kind": "param",
			"id": "b",
		},
		{
			"kind": "param",
			"id": "c"
		}
	]
}
```

In this manner we have successfully parsed the tree for a function declaration.

All the rules are spelled out after this section, but here is a cheat sheet:

- `"text"`: Exactly match "text"
- `<abcd>`: Match "a", "b", "c", or "d"
- `?rule`: Optionally match rule
- `+rule`: Match rule once or more
- `*rule`: Match rule zero or more times
- `!rule`: Fail if rule is matched
- `[rule]`: Like parenthesis in other languages
- `rule | rule`: Match either rule
- `rule rule`: Match both rules in a row

#### Literals

Literals begin and end with `"` and match text exactly, e.g. `"banana"`.

Literals have the following escape codes:
`\\`, `\n`, `\t`, `\r`, `\c`, `\l`, `\a`, `\b`, `\e`, and `\"`.

#### Sets

Sets begin and end with a `<` and `>` and match any single character contained in them.

For instance, `<abcd>` matches `a`, `b`, `c`, and `d`.

Sets share the literal escape codes (besides `\"`); additionally,
`<` and `>` may be in set expressions but must be escaped.

#### Optional

Optional-expressions begin with a `?`. They optionally match the inside expression.

For instance, `?"banana"` matches `banana` and `not banana`.

This seems useless, but is not, since it doesn't _consume_ code it doesn't match.

#### Star

Star expressions begin with a `*` and match 0 or more of the inside expression.

For instance,`*<abc>` matches `aaa`, `abb`, `acccb`, etc.

#### Plus

Plus expressions begin with a `+` and match 1 or more of the inside expression.

#### Brackets

Brackets begin and end with `[` and `]` and are analogous to parenthesis in other languages.

#### Sequence

If rules are in sequence, they will match text that follows that order.

For instance, `"banana phone" <!.>` matches only `banana phone.` and `banana phone!`

#### Choice

If rules are separated by pipes (`|`), they will match text that matches _any_ contained rule.

So, `"banana" | "phone"` matches both `banana` and `phone`.

Choices short-circuit; they will choose the first matching rule.

#### Guard

A guard matches any text that _doesn't_ match the inner expression.

A guard consumes no code.

It is useful to construct set differences, for instance:

```
lower: <abcdefghijklmnopqrstuvwxyz>
consonant: !<aeiou> lower
```

Guard expressions are difficult to read and should be used sparingly.
