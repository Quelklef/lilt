#[
Definiton of the AST _inside_ Lilt;
that is, the AST which is a Lilt construct;
that is, the AST used when _running_ Lilt code.
]#

import tables
import strutils
import sequtils
import json

import misc
import base

export base

proc `[]`*(node: Node, key: string): LiltValue =
    return node.properties[key]

proc `==`*(node: Node, other: Node): bool =
    return node.properties == other.properties

proc toJson*(node: Node): JsonNode
proc `$`*(node: Node): string =
    return $node.toJson
proc `$$`*(node: Node): string =
    return node.toJson.pretty

#~# JSON backend #~#

proc seqToJsonNode(se: seq[JsonNode]): JsonNode =
    result = newJArray()
    result.elems = se

proc toJson(prop: LiltValue): JsonNode =
    case prop.kind:
    of ltText:
        return %prop.text
    of ltNode:
        return toJson(prop.node)
    of ltList:
        return prop.list.map(toJson).seqToJsonNode

proc toJson*(node: Node): JsonNode =
    result = newJObject()
    result.fields["kind"] = % node.kind

    for key, prop in node.properties:
        result.fields[key] = toJson(prop)

#~#

proc initNode*(kind: string): Node =
    return Node(kind: kind, properties: newTable[string, LiltValue]())

proc initNode*(kind: string, props: TableRef[string, LiltValue]): Node =
    return Node(kind: kind, properties: props)

proc initNode*(kind: string, props: openarray[(string, LiltValue)]): Node =
    return Node(kind: kind, properties: props.newTable)

proc initNode*(kind: string, props: openarray[(string, string)]): Node =
    let properties = @props.mapIt( (it[0], LiltValue(kind: ltText, text: it[1])) ).newTable
    return Node(kind: kind, properties: properties)

proc initNode*(kind: string, props: openarray[(string, Node)]): Node =
    let properties = @props.mapIt( (it[0], LiltValue(kind: ltNode, node: it[1])) ).newTable
    return Node(kind: kind, properties: properties)

proc initNode*(kind: string, props: openarray[(string, seq[Node])]): Node =
    let properties = @props.mapIt( (it[0], LiltValue(kind: ltList, list: it[1])) ).newTable
    return Node(kind: kind, properties: properties)

#~# Pretty AST Creation Syntax #~#

proc toAst*(jast: JsonNode): Node =
    case jast.kind:
    of JString, JInt, JFloat, JBool, JNull, JArray:
        assert false
    of JObject:
        let fields = jast.fields
        var resultProps = newTable[string, LiltValue]()
        result = initNode(fields["kind"].str, resultProps)

        for field, val in fields:
            if field == "kind": continue

            case val.kind:
            of JString:
                resultProps[field] = initLiltValue(val.str)
            of JInt:
                resultProps[field] = initLiltValue($val.num)
            of JFloat:
                resultProps[field] = initLiltValue($val.fnum)
            of JBool:
                resultProps[field] = initLiltValue($val.bval)
            of JNull:
                resultProps[field] = initLiltValue("null")
            of JObject:
                resultProps[field] = initLiltValue(toAst(val))
            of JArray:
                resultProps[field] = initLiltValue(val.elems.mapIt(it.toAst))


template `~~`*(x: untyped): untyped =
  toAst(%* x)

