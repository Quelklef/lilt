
Legislators
===========

As most people know, `legislators make the rules <https://en.wikipedia.org/wiki/Legislator>`_. This applies in Lilt, too.

A legislator takes a bit of code and returns a rule based on it.


Literal
-------

One of the simplest legislators is the literal legislator, which returns a rule only matching exactly the given text.

Literal legislators begin and end with a double quote or single quote. Inbetween these two double quotes lies the content the resultant rule will match.

For instance, :code:`"banana"` will match any text beginning with "banana". Matching this text, it will consume 6 characters (the length of the word "banana") and return the text "banana". If the text doesn't start with "banana", the rule will fail.

Escape Sequences
~~~~~~~~~~~~~~~~

Literals may contain the following escape sequences

============ ================================
Key          Mapping
============ ================================
:code:`\\`   Literal backslash
:code:`\t`   Tab
:code:`\r`   Carriage return
:code:`\c`   Carriage return
:code:`\l`   Linefeed
:code:`\a`   Alert
:code:`\b`   Backspace
:code:`\e`   ESC
:code:`\'`   Literal '
:code:`\"`   Literal "
:code:`\>`   Literal >
:code:`\xHH` Character with given hex value
============ ================================


Set
---

Set legislators return a rule which matches any single character in the set.

Set legislators begin with a :code:`<` and end with a :code:`>`. Contained within are all the characters in the set.

For instance :code:`<abcdef>` will match "a", "b", "c", "d", "e", or "f". If it matches, it will consume the a single character and return it. If the text doesn't match, it will fail.

Sets have the same escape sequences as literals.

Sequence
--------

Sequence legislators are comprised of several rules in a row. Sequence legislators match text that matches all of the contained rules in order.

For instance, :code:`"word" " " "another"` is equivalent to :code:`"word another"`.

Slighyly more usefully, :code:`<ab> <?!>` matches "a?", "a!", "b?", and "b!".

Sequences always return text, concatenating together the text return values of their contined rules. Sequences will fail if any of the contained rules fail.


Choice
------

Choice legislators are also comprised of several rules. Choices return the return value of the first contained rule which matches the given text. The matching rule will also consume code, and possibly mutate the current state.

Choices are comprised of a sequence of rules, each separated by a pipe (`|`). Both a leading and a trailing pipe is allowed.

For instance, :code:`"firstname" | "lastname"` matches "firstname" and "lastname" only.

Choices will only fail if the given text matches none of the contained rules.

Ambiguous choices are allowed. For instance, :code:`"abc" | "abc"` is ambiguous -- does the text "abc" match the first rule, or the second? To solve this, the choice defers to the first matching rule.


Optional
--------

Optional legislators optionally match their contained rule. If the contained rule matches, the optional returns the value.

If the inner rule doesn't match, and would have returned a node, the optional returns nothing.

If the inner rule doesn't match, and would have returned text, the optional returns "".

If the inner rule doesn't match, and would have return a list of nodes, the optiional returns [].

Optionals begin with a :code:`?` and are followed by a rule.

For instance, :code:`?"fruit!"` applied to "fruit!" returns "fruit!" and applied to "NOT FRUIT" returns "".


Oneplus
-------

Oneplus legislators match their contained rule once or more.

They begin with :code:`+` and are followed by a rule.

If the inner rule returns text, the oneplus will return all the text returned by the inner rule concatenated together, similarly to a sequence.

For instance, :code:`*"a"` applied to "aaaaa" returns "aaaaa".

If the inner rule returns a node, the oneplus will similarly return a list of nodes.

Oneplus rules will only fail if the inner rule is not matched at least once.


Zeroplus
--------

Zeroplus legislators are like oneplus legislators, but match the inner rule zero or more times.

Zeroplus' begin with a :code:`*` and are followed by a rule.

:code:`*rule` is actually expanded to :code:`?+rule`; zeroplus legislators are macros.


Lambdas & States
----------------

Lambda legislators contain a rule and posses a mutable state.

They begin and end with :code:`{` and :code:`}`, containing the sequence/choice in between.

If the lambda doesn't contain any adjoinments, properties, or extensions, it will return the value of the contained rule.

Otherwise, the lambda will return the state, which can be text, a node, or a list of nodes, after the inner rule has run. As it runs, the state will be mutated.

For instance, :code:`{ *&"i" }` applied to "iiii" will return "iiii", just as :code:`*"i"` would. Though effectively the same, the two are semantically different. The former reads like: *zero or more times, append the text "i" to the state, returning it when complete*; the latter reads like: *match zero or more "i"s and return the consumed value*.

Result
------

Result legislators modify the current state, setting it to the value of the result's inner rule.

Results begin with a :code:`#` and are followed by any rule that doesn't return nothing.

For instance, :code:`_ #"banana" _` will match the text "      banana   ", returning "banana".

Results return nothing and fail when their inner rule fails.


Adjoinment
----------

Adjoinment legislators modify the current state, appending the text of the adjoinment's inner rule.

Adjoinments begin with a :code:`$` and are followed by a text-returning rule.

For instance, :code:`$"banana"` matches the text "banana", but instead of returning it, mutates the current state, appending the text "banana". This distinction is covered in the description of lambdas.

Adjoinments return nothing and fail when the inner rule fails.


Property
--------

Property legislators modify the current state, setting an attribute of the property's inner rule.

Properties consist of an identifier followed by a :code:`=` and a node-returning, text-returning, or node-list-returning rule.

For instance, :code:`fruit="grapes"` will match the text "grapes", setting the attribute "fruit" of the current state to the value "grapes".

Properties return nothing and fail when the inner rule fails.


Extension
---------

Extension legislators modify the current state, appending a node.

Extensions being with a :code:`&` and are followed by a node-returning rule.

For instance, if :code:`node` is a rule which matches the text "peach" and returns a node with the property :code:`{fruit: "peach"}`, :code:`&node` will match the text "peach", appending the resultant node to the state.

Extensions return nothing and fail when the inner rule fails.
