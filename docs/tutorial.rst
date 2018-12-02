
Lilt Tutorial
==============

.. _`JSON`: http://www.json.org/

Let's look at how one would parse `JSON`_ using Lilt. Instead of creating a parser generator to
begin, we'll start by creating a BNF-like Lilt specification for JSON, and then adding the
actual "parser generator" bits in afterwards.

Let's start with something simple, a JSON :code:`string`. For now, we'll skip implementing
escapes; backslashes will be handled literally, and :code:`"` will not be allowed in a string::
  
  string: '"' *anyNonQuoteCharacter '"'

We'll leave the rule :code:`anyNonQuoteCharacter` undefined for now.

So far, Lilt looks like any grammar specification, except using prefix notation rather than
postfix. We define a rule called :code:`string` (:code:`string:`) which consists of
a literal code (:code:`'"'`) followed by
0 or more (:code:`*`) of any non-quote character (:code:`anyNonQuoteCharacter`) and then a final, ending
literal quote (:code:`'"'`).

OK, fancy! Now let's define a number::

  number: ?"-" ["0" | +digit] ?["." *digit]

There are a few notable things about this snippet:

- :code:`"`: In this snippet, double quotes are used around literals
  rather than single quotes. It makes no difference.
- :code:`?`: This notates that the following rule is optional.
- :code:`[]`: Square prackets in Lilt are like parenthesis in other
  languages; they are used for precedence.
- :code:`+`: This matches the following rule 1 or more times.
- :code:`|`: Several rules separated by :code:`|` will match code
  that matches *any* of the rules. So, :code:`'a' | 'b'` will match
  "a", "b", any nothing else.

Just for fun, let's also allow the exponent synax::

  number: ?"-" ["0" | +digit] ?["." *digit] ?[["e" | "E"] ["+" | "-"] +digit]

:code:`["e" | "E"]` is a little verbose; luckily, though, there's some syntactic
sugar we can use! We can enclose many characters in angle brackets
:code:`<like this>`, which will match any of the contained characters. For
instance, the :code:`digit` builtin is equivalent to :code:`<1234567890>`.

So, we may rewrite this slightly more tersely as::

  number: ?"-" ["0" | +digit] ?["." *digit] ?[<eE> <+-> +digit]

Cool, now we've defined what :code:`string`s and :code:`number`s look like. Before we continue,
though, there's one important conceptual detail that need to be ironed out.

It's very easy to look at these definitions as predicates; it's easy to think of :code:`number`
as a function that takes some code and returns whether or not it matches the specification (i.e.
looks like a number). However, it's important to *not* do this in order to better grok how Lilt
works. Instead, think of :code:`number` (and all other rules) as a function that takes some
code, tries to match it to the specification, and returns the concused code if it matches. If it *doesn't*
match, it will fail, and signal to the caller that it has failed.
So, :code:`number("123") = "123"` and :code:`number("123 abc") = "123"` and :code:`number("x")` fails.

Now it's time to revisit :code:`anyNonQuoteCharacter`, which we left undefined
before but can now think about since we've got our conception all fixed up.

In order to define this, We introduce the :code:`!` operator, called the guard operator. The
guard operator will fail if and only if the contained rule *doesn't* fail. So :code:`!"2"` fails ONLY
on "2", and :code:`!digit` fails on any digit.

Why is this useful? It allows us to create set differences. Some set :code:`A - B`
would be expressed in Lilt as :code:`!B A`. For instance, we can replace :code:`anyNonQuoteCharacter`
with :code:`!'"' any`. :code:`any` is a builtin that matches any character.

Now, we can complete our JSON specification (except for string escapes)::

  value: string | number | object | array | "true" | "false" | "null"

  string: '"' *[!'"' any] '"'

  number: ?"-" ["0" | +digit] ?["." *digit] ?[<eE> <+-> +digit]

  object: "{" _ ?[pair *["," pair]] _ "}"
  pair: string ":" value

  array: "[" _ ?[value *["," value]] _ "]"

Fancy stuff. Look at that!

Now we can finally get to the "parser" part of "parser generator". Instead of just returning some
*code*, we want our specification to return an *abstract syntax tree*. Before we start changing
the JSON specifiction, let's learn how Lilt represents ASTs.

In Lilt, an AST node is one of 3 things:

- Code (a string)
- List (a list of Nodes)
- Node (an object with properties that are other AST nodes)

Note that "node" and "Node" are subtly different here, since a "node" may be Code, a List, or a Node.
All Nodes are nodes; some nodes are Nodes.

We represent Lilt nodes in a manner similar to JSON. To exemplify, let's create a node for the function
call: :code:`printLn(x, y, z)`. We will want a Node for the whole call which will have a "target" attribute that
represents the function reference as well as a "arguments" attribute which is a list of references.
Each reference will also be a Node with a "to" attriubte which is just the literal name of the reference::

  call {
    target: reference { to: "printLn" }
    arguments: [
      reference { to: "x" }
      reference { to: "y" }
      reference { to: "z" }
    ]
  }

Since this is not formal code, and is just shorthand, commas aren't really needed.

Now let's design an AST for our spec. Take another look at the spec so far::

  value: string | number | object | array | "true" | "false" | "null"

  string: '"' *[!'"' any] '"'

  number: ?"-" ["0" | +digit] ?["." *digit] ?[<eE> <+-> +digit]

  object: "{" _ ?[pair *["," pair]] _ "}"
  pair: string ":" value

  array: "[" _ ?[value *["," value]] _ "]"

Let's consider how we want to generate the AST.

:code:`string` should probably be a Node with a "value" attribute containing the code
of the string.

:code:`number` should probably be a Node with a "wholes" attribute containing the digits before
the decimal point. It may also have a "digit" attribute containing the digits after the decimal point
and an "exponent" attribute containing the digits after an "e" or "E".

:code:`object` should be a Node with a "pairs" attribute, a List of pairs. Each :code:`pair` should
be a Node with a "key" attriubte and a "value" attribute.

Finally, :code:`array` should be a node with an "items" attribute, a list of Nodes of the contained
values.

Great! But, there's an issue. :code:`string`, :code:`number`, :code:`object`, and :code:`array`
will all evaluate to *Nodes*, but :code:`"true"`, :code:`"false"`, and :code:`"null"` will all
evaluate to *Code*. This means that :code:`value` cannot certainly evaluate to a *Node* nor
certainly evaluate to some *Code*. Since Lilt rules must be homogenous (i.e. return one and only one type), this isn't
allowed. To fix it, we need to somehow return a Node for the literals as well.

We'll create :code:`trueLiteral`, :code:`falseLiteral`, and :code:`nullLiteral` rules which will do that.
They will return a Node which has *no* attriubutes. Lilt Nodes are implicitely given an attribute
that is the name of the rule that defined them, so these blank nodes will still be distinguishable.

Phew, close one. Now, how do we reify our plan?

Named attributes are notated like :code:`someAttribute=rule`, which will set :code:`someAttribute` to
the value of :code:`rule` on the returned Node. Let's start small and reimplement :code:`number`::

  number: ?negative="-" wholes=["0" | +digit] ?["." decimals=*digit] exponent=?[<eE> <+-> +digit]

Pretty simple! Let's see it in action::

  number("-4.0") =
    number {
      negative: "-"
      wholes: "4"
      decimals: "0"
    }

  number("6.022e+23") =
    number {
      wholes: "6"
      decimals: "022"
      exponent: "e+23"
    }

  number("14") = number { wholes: "14" }

Hmmm, the "exponent" attribute is kind of ugly. It would be nice to actually parse the exponent as well,
so let's do that::

  number: ?negative="-" wholes=["0" | +digit] ?["." decimals=*digit] ?exponent=numberExp
  numberExp: <eE> sign=<+-> digits=+digit

Now, this parses nicer::

  number("6.022e+23") =
    number {
      wholes: "6"
      decimals: "022"
      exponent: numberExp {
        sign: "+"
        digits: "23"
      }
    }

So that's how we create nodes. We'll also need to be able to create Lists and Code as well.

So far, Code has just been created with literals like :code:`"0"` and operations on literals
like :code:`*digit`. That will actually be enough for JSON, but there are other ways to create
Code that will be reviewed at the end of the tutorial
    
Lists can be created by applying :code:`*` or :code:`+` to a Node-returning rule, so :code:`*number`
will be a List. However, it can also be created explicitly with :code:`&`. :code:`&` will append a node
to the resultant list. To exemplify, let's implement :code:`array` next::

  array: "[" _ items=?items _ "]"
  items: &value *["," &value]

Since, as we planned before, :code:`value` will return a Node, then each call to :code:`&` will append
that node to the resultant list of :code:`items`, which will be returned when finished. let's
see an :code:`array` example! Since we've only defined :code:`number` as well as :code:`array`, it will
be an array of numbers::

  array("[1, 2, 3.4, 5.6, 7]") =
    array {
      items: [
        number { wholes: "1" }
        number { wholes: "2" }
        number { wholes: "3", decimals: "4" }
        number { wholes: "5", decimals: "6" }
        number { wholes: "7" }
      ]
    }

Knowing :code:`attr=` and :code:`&` actually gives us enough to finish making a real JSON parser::

  value: string | number | object | array | trueLiteral | falseLiteral | nullLiteral

  trueLiteral: _="" "true"
  falseLiteral: _="" "false"
  nullLiteral: _="" "null"

  string: '"' value=*[!'"' any] '"'

  number: ?negative="-" wholes=["0" | +digit] ?["." decimals=*digit] ?exponent=numberExp
  numberExp: <eE> sign=<+-> digits=+digit

  object: "{" _ pairs=?pairs _ "}"
  pairs: &pair *["," &pair]
  pair: key=string ":" value=value

  array: "[" _ items=?items _ "]"
  items: &value *["," &value]

Real quick: Remember when I said :code:`trueLiteral`, :code:`falseLiteral`, and :code:`nullLiteral` would
make an object with no attributes? I lied. That's not (yet) possible in Lilt, so instead we consume
:code:`""`, which will always succeed, and set it to the dummy attribute "_".

Great! We have a *real, working* JSON parser! And in only 12 lines of code! You'll notice that in
the transition from grammar to parser, we had to add some auxiliary functions in order to work
with the type system: :code:`trueLiteral`, :code:`falseLiteral`, :code:`nullLiteral` :code:`numberExp`,
:code:`pairs`, and :code:`items`. But perhaps we don't want these auxiliary functions?

Let's say we hate that :code:`items` has to be defined as its own rule and wish we could just inline
it within :code:`array`. What would happen if we did?::

  array: "[" _ items=?[&value *["," &value]] _ "]"

Now, this would confuse the type system. Since :code:`[]` doesn't introduce a new scope, :code:`items=`
says that :code:`array` will return a *Node*,
but then :code:`&value` says that :code:`array` will return a *List*!

This can be solved with :code:`{}`, which is like :code:`[]` but *does* introduce a new scope
and are used to create anonymous, inline rules. So a working version would be::

  array: "[" _ items=?{&value *["," &value]} _ "]"

Now :code:`&value` affects the *inner* rule rather than :code:`array`, and everything is hunky-dory.

Since anonymous classes are, well, anonymous, they generally shouldn't return a Node. As mentioned before,
all nodes contain an attribute which refers to the rule that generated them. What should that be for
a node created by an anonymous rule?

Anyway, now we can make the JSON definition more terse. If we inline all the (non-Node) auxiliary functions, it
would look like:::

  value: string | number | object | array | trueLiteral | falseLiteral | nullLiteral

  trueLiteral: _="" "true"
  falseLiteral: _="" "false"
  nullLiteral: _="" "null"

  string: '"' value=*[!'"' any] '"'

  number: ?negative="-" wholes=["0" | +digit] ?["." decimals=*digit] ?exponent=numberExp
  numberExp: <eE> sign=<+-> digits=+digit

  object: "{" _ pairs=?{&pair *["," &pair]} _ "}"
  pair: key=string ":" value=value

  array: "[" _ items=?{&value *["," &value]} _ "]"

We didn't inline :code:`numberExp` since it returns a Node.

We're almost done! We just have to make it handle escapes in strings, and whitespace. Let's do strings first.

First, let's replace the :code:`string` definition with::

  string: '"' value=*stringChar '"'

Now we just have to define :code:`stringChar`. Well, it's any character besides :code:`"` or baclslash, or
a blackslash followed by any of: :code:`"\/bfnrt`, or a :code:`u` and 4 hexadecimal digits. Let's do it::

  stringChar: [!<"\\> any] | "\\" [</\\bfnrt> | "u" hexDig hexDig hexDig hexDig]
  hexDig: <1234567890ABCDEFabcdef>

Now, :code:`string` will correctly consume :code:`"string \""`. It will NOT interpret the backslash and
map it to a double quote; the returned text will be :code:`string \"`. Let's include it in the parser::

  value: string | number | object | array | trueLiteral | falseLiteral | nullLiteral

  trueLiteral: _="" "true"
  falseLiteral: _="" "false"
  nullLiteral: _="" "null"

  string: '"' value=*stringChar '"'
  stringChar: [!<"\\> any] | "\\" [</\\bfnrt> | "u" hexDig hexDig hexDig hexDig]
  hexDig: <1234567890ABCDEFabcdef>

  number: ?negative="-" wholes=["0" | +digit] ?["." decimals=*digit] ?exponent=numberExp
  numberExp: <eE> sign=<+-> digits=+digit

  object: "{" _ pairs=?{&pair *["," &pair]} _ "}"
  pair: key=string ":" value=value

  array: "[" _ items=?{&value *["," &value]} _ "]"

One final job: Whitespace. Lilt includes a builtin function :code:`_` which consumes 0 or more whitespace
characters and returns them. It may be *tempting* to implement whitespace for :code:`value` like this::

  value: _ [string | number | object | array | trueLiteral | falseLiteral | nullLiteral] _

but that won't work. Why not? The type system will see that :code:`_` returns Code and will make
:code:`value` return Code *as well*, returning what it's consumed. Instead, we want it to return
a Node. We can do this with the :code:`#` operator, which is kind of like :code:`return`; it will
return the notated value. It doesn't return it until the end of the call, though, so the second
call to :code:`_` will still work, consuming trailing whitespace. The correct code looks like::

  value: _ #[string | number | object | array | trueLiteral | falseLiteral | nullLiteral] _

(Excuse the misplaced italics)

Note that since :code:`#` doesn't stop execution, it's not *quite* like :code:`return`. Since it
doesn't stop execution, multiple calls to :code:`#` will overwrite each other, the last value is
the one that will be returned. So for :code:`ex: #"a" #"b"`, :code:`ex("ab") = "b"`.

OK, let's fill in whitespace::

  value: _ #[string | number | object | array | trueLiteral | falseLiteral | nullLiteral] _

  trueLiteral: _="" "true"
  falseLiteral: _="" "false"
  nullLiteral: _="" "null"

  string: '"' value=*stringChar '"'
  stringChar: [!<"\\> any] | "\\" [</\\bfnrt> | "u" hexDig hexDig hexDig hexDig]
  hexDig: <1234567890ABCDEFabcdef>

  number: ?negative="-" wholes=["0" | +digit] ?["." decimals=*digit] ?exponent=numberExp
  numberExp: <eE> sign=<+-> digits=+digit

  object: "{" _ pairs=?{&pair *["," &pair]} _ "}"
  pair: _ key=string _ ":" _ value=value _

  array: "[" _ items=?{&value *["," &value]} _ "]"

Aaand we're done! A working JSON parser in just 9 lines of code.

Unfortunately, the tutorial is not quite done. One operator has escaped its scope, and that is
adjoinment, notated by :code:`$`. Rules containing :code:`$` will consume, but not return, most
consumed code. Only code passed to :code:`$` will be *adjoined* and returned. So, for::

  ex: "prefix " $"value" " postfix"

:code:`ex("prefix value postfix") = "value"`.

The final bit to learn is the comment. Line comments start with :code:`/` and continue to the end
of the line, and block and inline comments look :code:`((like this))`.

Actually using this in Nim is not too difficult and is covered in `usage <usage.html>`.

