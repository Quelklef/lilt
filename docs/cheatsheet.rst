
Lilt Cheatsheet
===============

Constructs
----------

================================ ================================ ========================================
Construct name                   Syntax                           Semantics                               
================================ ================================ ========================================
Line comments (unimplemented)    :code:`/text`                    Ignored by the parser
Inline & block comments (unimp.) :code:`/(text)`                  Ignored by the parser
Brackets                         :code:`[code]`                   Like parenthesis
Definition                       :code:`identifier: body`         Defines a rule
Reference                        :code:`ruleName`                 References / "calls" a named rule
Literal                          :code:`"text"`                   Matches exact text
Set                              :code:`<characters>`             Matches any single contained character
Sequences                        :code:`rule1 rule2 ...`          Matches several rules in order
Choice                           :code:`rule1 | rule2 | ...`      Matches any of several rules
Optional                         :code:`?rule`                    Optionally matches a rule
Oneplus                          :code:`+rule`                    Matches a rule once or more
Zeroplus                         :code:`*rule`                    Matches a rule zero or more times
Lambda                           :code:`{rule}`                   Makes a new state for `rule`
Adjoinment                       :code:`$rule`                    Appends text from `rule` to state
Property                         :code:`key=rule`                 Maps `key` to value from `rule` on state
Extension                        :code:`&rule`                    Appends a node to the state
================================ ================================ ========================================


Builtins
--------

================================ ===================================================
Name                             Description or equivalent code
================================ ===================================================
:code:`any`                      Matches any single character
:code:`whitespace`               Matches any single whitespace character
:code:`_`                        `*whitespace`
:code:`lower`                    `<abcdefghijklmnopqrstuvwxyz>`
:code:`upper`                    `<ABCDEFGHIJKLMNOPQRSTUVWXYZ>`
:code:`alpha`                    `lower | upper`
:code:`digit`                    `<1234567890>`
:code:`alphanum`                 `alpha | digit`
================================ ===================================================
