
Cheatsheet
==========

Constructs
----------

======================= ================================ ====================================================
Construct name          Syntax                           Semantics                               
======================= ================================ ====================================================
Line comments           :code:`/text`                    Ignored by the parser
Inline & block comments :code:`((text))`                 Ignored by the parser
Brackets                :code:`[code]`                   Like parenthesis
Definition              :code:`identifier: body`         Defines a rule
Reference               :code:`ruleName`                 References / "calls" a named rule
Literal                 :code:`"text"` or :code:`'text'` Matches exact text
Set                     :code:`<characters>`             Matches any single contained character
Sequences               :code:`rule1 rule2 ...`          Matches several rules in order
Choice                  :code:`rule1 | rule2 | ...`\*    Matches any of several rules
Optional                :code:`?rule`                    Optionally matches a rule
Oneplus                 :code:`+rule`                    Matches a rule once or more
Zeroplus                :code:`*rule`                    Matches a rule zero or more times
Lambda                  :code:`{rule}`                   Makes a new state for :code:`rule`
Result                  :code:`#rule`                    Sets the state to value from :code:`rule`
Adjoinment              :code:`$rule`                    Appends text from :code:`rule` to state
Property                :code:`key=rule`                 Maps :code:`key` on state to value from :code:`rule`
Extension               :code:`&rule`                    Appends a node to the state
======================= ================================ ====================================================

\* Leading and trailing pipes are allowed

Builtins
--------

================================ ===================================================================
Name                             Description or equivalent code
================================ ===================================================================
:code:`any`                      Matches any single character except :code:`\0`
:code:`newline`                  :code:`+<\c\l>`. Use in lieu of :code:`\n`, which doesn't exist.
:code:`whitespace`               Matches any single whitespace character
:code:`_`                        :code:`*whitespace`
:code:`lower`                    :code:`<abcdefghijklmnopqrstuvwxyz>`
:code:`upper`                    :code:`<ABCDEFGHIJKLMNOPQRSTUVWXYZ>`
:code:`alpha`                    :code:`lower | upper`
:code:`digit`                    :code:`<1234567890>`
:code:`alphanum`                 :code:`alpha | digit`
================================ ===================================================================
