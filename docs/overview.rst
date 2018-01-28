
Lilt Overview
=============

.. _`parser generator`: https://en.wikipedia.org/wiki/Compiler-compiler

Lilt is a `parser generator`_. It accepts a specification and returns a parser based on that specification.

Specifications look a lot like grammar specifications, because they are a superset of grammar specifications.


Abstract Syntax Trees and Lilt
------------------------------

.. _`abstract syntax tree`: https://en.wikipedia.org/wiki/Abstract_syntax_tree

Lilt parsers parse *text* into an `abstract syntax tree`_ based on the specification the parser was generated from.

Lilt's ASTs slightly differ from typical ASTs. Most AST nodes consist of a kind/type, a value, and 0 or more ordered children, which are also nodes. Lilt's ASTs instead consist of a kind/type, and 0 or more named properties. These properties may be text, nodes, or lists of nodes. The text properties are analogous to the value of typical ASTs, and the node and list properties are analogous to the children of typical ASTs. As such, both kinds of ASTs possess the same functionality, just delivered slightly differently.


Rules
-----

The *rule* is the basic idea of Lilt. Rules act on *text* and do several things:

- Consume some zero or positive nonzero amount of text
- Return some text, a node, a list of nodes, or nothing
- Mutate the current state
- Alternatively, a rule may fail, consuming nothing, returning nothing, mutating nothing, and signaling failure to the parent rule (which may choose to ignore it).


Legislators
-----------

As most people know, legislators make the rules. This rule applies in Lilt, too.

A *legislator* takes a bit of code and returns a rule based on it. 
