
## Lilt

Lilt is a language for writing parsers.

Lilt, in fact, stands for:

```
L - Super
I - Duper
L - Easy
T - Parsing
```

A finished piece of Lilt code acts as a function which takes some text and generates
an AST from it.

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
6. The Non-Lilt AST will be called the "generated tree" or "tree".

As such, a piece of Lilt code is run through a parser and interpreted as a generator which acts on text.

***

The fundamental idea of Lilt is a _rule_. A Rule can be though of as a function of text.
A rule is given some text, and does a few things:

- The rule consumes part of the text
- The rule returns one of:
	- A node on the generated tree,
	- A piece of text,
	- A list of nodes.
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

***

### Formal Specification

#### Literals

Literals begin and end with `"` and match text exactly, e.g. `"banana"`.

Literals have the following escape codes:
`\\`, `\n`, `\t`, `\r`, `\c`, `\l`, `\a`, `\b`, `\e`, and `\"`.

#### Sets

Sets begin and end with a `<` and `>` and match any single character contained in them.

For instance, `<abcd>` matches `a`, `b`, `c`, and `d`.

Sets share the literal escape codes (besides `\"`); additionally,
`<` and `>` may be in set expressions but must be escaped.

#### Reference

A reference is as you'd expect, it calls another defined rule.

Ex:

```
vowel: <aeiou>
vowelString: *vowel
```

#### Optional

Optional-expressions begin with a `?`. They optionally match the inside expression.

For instance, `?"banana"` matches `banana` and `not banana`.

This seems useless, but is not, since it doesn't _consume_ code it doesn't match.

#### Star

Star expressions begin with a `*` and match 0 or more of the inside expression.

For instance,`*<abc>` matches `aaa`, `abb`, `acccb`, etc.

#### Plus

Plus expressions begin with a `+` and match 1 or more of the inside expression.

#### Guard

A guard matches any text that _doesn't_ match the inner expression.

A guard consumes no code.

It is useful to construct set differences, for instance:

```
lower: <abcdefghijklmnopqrstuvwxyz>
consonant: !<aeiou> lower
```

Guard expressions are difficult to read and should be used sparingly.

#### Brackets

Brackets begin and end with `[` and `]` and are analogous to parenthesis in other languages.

#### Sequence

If rules are in sequence, they will match text that follows that order.

For instance, `"banana phone" <!.>` matches only `banana phone.` and `banana phone!`

#### Choice

If rules are separated by pipes (`|`), they will match text that matches _any_ contained rule.

So, `"banana" | "phone"` matches both `banana` and `phone`.

Choices short-circuit; they will choose the first matching rule.

#### Adjoinment

An adjoinment looks like `$rule` appends text to the result of a rule.

Ex:
```
char: <abc>
stringValue: "\"" $*char "\""
```

`stringValue` applied to `"aaabbbccc"` will return `aaabbbccc` (notice no quotes).

If a definition has no adjoinments in it, no properties, and no extensions, it will, by default,
return all code consumed. As such, It can be thought that the "default" is for a rule to be an
adjoinment.

#### Property

A property looks like `propertyName=rule` and adds a property with name
`propertyName` and value `rule` to the resultant node.

Ex:
```
vowel: <aeiou>
vowelNode: string=*vowel
```

`vowelNode` applied to `aooui` returns the node:

```JSON
{
	"kind": "vowelNode",
	"string": "aooui"
}
```

#### Extension

An extension looks like `&rule` and appends the result of `rule` (which must be a node) to
the resultant list

Ex:
```
exNode: text="banana"
multipleBananas: *&exNode
```

`multipleBananas` applied to "bananabananabananabanana" returns the node list:

```JSON
[
	{
		"kind": "exNode",
		"text": "banana"
	},
	{
		"kind": "exNode",
		"text": "banana"
	},
	{
		"kind": "exNode",
		"text": "banana"
	},
	{
		"kind": "exNode",
		"text": "banana"
	}
]
```

### Lambda

A lambda is an inline rule. The syntax looks like: `{ body }`.

Lambdas are useful to create one-off rules, for instance:

```
identifier: *<abcdefghijklmnopqrstuvwxyz>
arg: id=identifier
funcDecl: "func " id=identifier "(" args={ &arg *[", " &arg] } ");"
```

Note that the `&` works in relation to the _lambda_, not `funcDecl`. This is why they're useful.
