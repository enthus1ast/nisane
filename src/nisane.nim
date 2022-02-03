# TODO
# DONE bool
# DONE ref object
# DONE to macro "nil" should skip
# TODO defaults and modifiers for the create macros with custom pragmas
# Beef: Depending on what you want you could use disruptek's assume package which has typeit allowing you to iterate fields of objects
# Beef: https://github.com/disruptek/assume/blob/master/tests/typeit.nim#L102-L199

import macros, strutils, strformat, tables
import typehelpers
import typehelpers2

proc toString*(str: string): string = str
proc toFloat*(str: string): float {.inline.} = parseFloat(str)
proc toInt*(str: string): int {.inline.} = parseInt(str)
proc toInt64*(str: string): int64 {.inline.} = str.toInt().int64
proc toBool*(str: string): bool {.inline.} = parseBool(str)
proc toChar*(str: string): char {.inline.} = str[0]

template defaultValue*(def: string | int | float) {.pragma.} ## does not work yet :/
# template defaultValue*() {.pragma.}

macro to*(se: untyped, tys: varargs[typed]): typed =
  ## a generic seq/openarray unpacker.
  runnableExamples:
    type Obj = object
      bb: int
      cc: bool
    var se = ["1337","somethingToSkip", "foo", "1", "true"]
    var id: int
    var obj = Obj()
    se.to(id, nil, obj)
    assert obj.aa == "foo"
    assert obj.bb == 1
    assert obj.cc == true
  result = newStmtList()
  var seqidx = 0
  for ty in tys:
    if (repr ty) == "nil": # Skip this type
      seqidx.inc
      continue
    let (kind, tyy) = ty.gType
    case kind
    of TyString, TyInt, TyInt64, TyBool, TyFloat:
      let ex = $ty & " = "  & (repr se)  & "[" & $seqidx  & "]"  & ".to" & ty.getType.strval.capitalizeAscii
      result.add parseStmt(ex)
      seqidx.inc
    of TyObj:
      for idx, el in tyy.pairs:
        let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & (repr se)  & "[" & $seqidx  & "]" & ".to" & el[1].strval.capitalizeAscii
        result.add parseStmt(ex)
        seqidx.inc
    of TyRefObj:
      for idx, el in tyy.pairs:
        let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & (repr se)  & "[" & $seqidx  & "]" & ".to" & el[1].strval.capitalizeAscii
        result.add parseStmt(ex)
        seqidx.inc
    of TyTuple:
      for idx, el in tyy.pairs:
        let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & (repr se)  & "[" & $seqidx  & "]" & ".to" & el[1].strval.capitalizeAscii
        result.add parseStmt(ex)
        seqidx.inc
    of TyUnsupported:
      echo "Unsupported!"


proc mapToSqlType*(nimType: string): string =
  ## Maps nim type to sql type.
  case nimType.toLowerAscii()
  of "int": return "INTEGER"
  of "int64": return "INTEGER"
  of "float": return "REAL"
  of "string": return "TEXT"
  of "bool": return "BOOLEAN"
  else: return "TEXT"


macro ct*(ty: typed, mapping: proc(nimType: string): string = mapToSqlType): string =
  ## create table macro
  # echo "####"
  # echo treeRepr ty
  # echo ty.hasCustomPragma(defaultValue)
  # echo treeRepr ty.getTypeInst
  # echo ty.getTypeInst.hasCustomPragma(defaultValue)
  # echo "CT###################### ", repr $ty.gType()
  var tyName = $ty

  var lines: seq[string] = @[]
  let (kind, tyy) = gType(ty)
  case kind
  of TyObj, TyRefObj, TyTuple:
    # echo treeRepr(tyy)
    for idx, el in tyy.pairs:
      let name = toStrLit(el[0]).strval
      let nimType = el[1].strval
      let sqlType = nimType.mapToSqlType()
      var ex = fmt"{name} {sqlType} NOT NULL"
      # echo "HAS CUSTOM PRAGMA:", hasCustomPragma(el[0][1], defaultValue)
      # echo "EX  ", ex
      lines.add ex
  else:
    echo "Unsupported"

  echo "TYPE PRAGMA: ##########################"
  let pragmas = ty.typePragma()
  if pragmas.hasKey("tablename"):
    tyName = pragmas["tablename"].strVal
  var sq = fmt"CREATE TABLE IF NOT EXISTS {tyName}(" & "\n"
  sq &=  "\t" & "id INTEGER PRIMARY KEY,\n"
  for idx, line in lines.pairs():
    sq &= "\t" & line
    if idx < lines.len - 1:
      sq &= ","
    sq &= "\n"
  sq &= ");"
  return newLit(sq)


macro ci*(ty: typed): string =
  ## create insert
  # INSERT INTO Foo (first, second, third, forth) VALUES (?, ?, ?, ?)
  var tyName = $ty
  var lines: seq[string] = @[]
  let (kind, tyy) = gType(ty)
  case kind
  of TyObj, TyTuple, TyRefObj:
    for idx, el in tyy.pairs:
      lines.add $el[0]
  else:
    echo "Unsupported"
    return

  let pragmas = ty.typePragma()
  if pragmas.hasKey("tablename"):
    tyName = pragmas["tablename"].strVal

  var sq = fmt"INSERT INTO {tyName}("
  for idx, line in lines.pairs:
    sq &= line
    if idx < lines.len - 1:
      sq &= ", "
  sq &= ") VALUES ("
  for idx, _ in lines.pairs:
    sq &= "?"
    if idx < lines.len - 1:
      sq &= ", "
  sq &= ")"
  return newLit(sq)

macro an*(ty: typed): string =
  ## returns all the objects AttributeNames
  var lines: seq[string] = @[]
  let (kind, tyy) = gType(ty)
  case kind
  of TyObj, TyTuple, TyRefObj:
    for idx, el in tyy.pairs:
      lines.add $el[0]
  else:
    echo "Unsupported"
    return
  var sq = ""
  for idx, el in lines.pairs:
    sq &=  $el
    if idx < lines.len - 1:
      sq &= ", "
  return newLit(sq)

macro csv*(ty: typed, withId: static bool = false): string =
  ## create select value
  ## this creates a string:
  ## "SELECT foo, baa, baz FROM Typename"
  var tyName = $ty
  var lines: seq[string] = @[]
  let (kind, tyy) = gType(ty)
  case kind
  of TyObj, TyTuple, TyRefObj:
    for idx, el in tyy.pairs:
      lines.add $el[0]
  else:
    echo "Unsupported"
    return
  var sq = "SELECT "
  if withId:
    sq &= "id, "
  for idx, el in lines.pairs:
    sq &=  $el
    if idx < lines.len - 1:
      sq &= ", "

  let pragmas = ty.typePragma()
  if pragmas.hasKey("tablename"):
    tyName = pragmas["tablename"].strVal
  sq &= fmt" FROM {tyName}"
  return newLit(sq)


when isMainModule:
  type
    FooBaa = object {.defaultValue: "FAA".}
      # id: int
      first {.defaultValue: "ff".}: string
      second: string
      third {.defaultValue: 0.1337.}: float
      forth: int

when isMainModule and true:
  import print
  import db_sqlite

  type
    Foo {.tablename: "Fax".} = object
      first: string
      second: string
      third: float
      forth: int
    Foo2 = object
      first: string
      second: string
      third: float
      forth: int

  echo ct(Foo)

  var db = open(":memory:", "", "", "")
  db.exec(sql ct(Foo))
  db.exec(sql ct(Foo2))

  for idx in 0..10:
    db.exec(sql ci(Foo), $idx & "first", "second", "13.37", "123")
    db.exec(sql ci(Foo2), $idx & "first", "second", "13.37", "123")

    db.exec(sql ci(Foo), $idx & "adfsadfff", "fffasdf", "13.37", "123")
    db.exec(sql ci(Foo2), $idx & "fasdfwefew", "fwef32fwef3", "13.37", "123")

  for row in db.getAllRows(sql"select * from Fax, Foo2 where Fax.id = Foo2.id"):
    var foo: Foo = Foo()
    var foo2: Foo2 = Foo2()
    to(row, nil, foo, nil, foo2) # skip elements with nil (eg: table id's)

  var idxA: int = -1
  var idxB: int = -1
  type AB = object
    aa: int
    bb: int
  for row in db.getAllRows(sql"select count(Fax.id), count(Foo2.id) * 2  from Fax, Foo2 where Fax.second = ? and Foo2.second = ? ", "fffasdf", "fwef32fwef3"):
    echo row
    var ab = AB()
    var aa: int
    var bb: int
    expandMacros:
      row.to(ab)
    expandMacros:
      row.to(aa, bb)
      # row.to(idxA, idxB)
    echo ab
    print aa, bb

when isMainModule and true:
  import print
  import unittest
  # import json

  type
    FooTst = object
      first: string
      second: string
      third: float
      fourth: int
    Baa = object
      bfirst: string
      bsecond: string
    RBaa = ref object
      bfirst: string
      bsecond: string
    TBaa = tuple[bfirst, bsecond: string]

  var row = @["1", "first", "second", "13.37", "123", "2", "bfirst", "bsecond"]
  suite "nisane":
    test "simple":
      var ii: int
      var ss: string
      row.to(ii, ss)
      check ii == 1
      check ss == "first"
    test "id + Obj":
      var id: int
      var obj: FooTst
      row.to(id, obj)
      check id == 1
      check obj.first == "first"
      check obj.second == "second"
      check obj.third == 13.37
      check obj.fourth == 123
    test "id + Obj + id2 + Obj2":
      var id: int
      var obj: FooTst
      var id2: int
      var obj2: Baa
      row.to(id, obj, id2, obj2)
      check id == 1
      check obj.first == "first"
      check obj.second == "second"
      check obj.third == 13.37
      check obj.fourth == 123
      check id2 == 2
      check obj2.bfirst == "bfirst"
      check obj2.bsecond == "bsecond"
    test "tuple":
      var tup: tuple[a: int, b: string, c: string, d: float, e: int]
      var id2: int
      var obj2 = Baa()
      row.to(tup, id2, obj2)
      check tup.a == 1
      check tup.b == "first"
      check tup.c == "second"
      check tup.d == 13.37
      check tup.e == 123
      check id2 == 2
      check obj2.bfirst == "bfirst"
      check obj2.bsecond == "bsecond"
    test "bool":
      var se = ["1", "true"]
      var id: int
      var bb: bool
      se.to(id, bb)
      check id == 1
      check bb == true
    test "ref obj":
      var se = ["1", "foo", "true"]
      type Robj = ref object
        ii: int
        ss: string
        bb: bool
      var robj = Robj()
      se.to(robj)
      check robj.ii == 1
      check robj.ss == "foo"
      check robj.bb == true
    test "skip with 'nil'":
      var se = ["1", "foo", "true"]
      type Obj = object
        ss: string
        bb: bool
      var robj = Obj()
      se.to(nil, robj)
      check robj.ss == "foo"
      check robj.bb == true
    # test "ref str":
    #   var se = ["foo"]
    #   type Rstr = ref string
    #   var rstr: Rstr
    #   se.to(rstr)
    #   # check rstr == foo
    # test "json":
    #   proc toJson(str: string): JsonNode = parseJson(str)
    #   var se = ["{\"a\": [1,2,3]}"]
    #   var js = %* {}
    #   se.to(js)
    #   echo js
    test "ci object":
      check ci(Baa) == "INSERT INTO Baa(bfirst, bsecond) VALUES (?, ?)"
    test "ci ref object":
      check ci(RBaa) == "INSERT INTO RBaa(bfirst, bsecond) VALUES (?, ?)"
    test "ci tuple":
      check ci(TBaa) == "INSERT INTO TBaa(bfirst, bsecond) VALUES (?, ?)"
    test "ct object":
      check ct(Baa) == unescape "\"CREATE TABLE IF NOT EXISTS Baa(\x0A\x09id INTEGER PRIMARY KEY,\x0A\x09bfirst TEXT NOT NULL,\x0A\x09bsecond TEXT NOT NULL\x0A);\""
    test "ct ref object":
      check ct(RBaa) == unescape "\"CREATE TABLE IF NOT EXISTS RBaa(\x0A\x09id INTEGER PRIMARY KEY,\x0A\x09bfirst TEXT NOT NULL,\x0A\x09bsecond TEXT NOT NULL\x0A);\""
    test "ct tuple":
      check ct(TBaa) == unescape "\"CREATE TABLE IF NOT EXISTS TBaa(\x0A\x09id INTEGER PRIMARY KEY,\x0A\x09bfirst TEXT NOT NULL,\x0A\x09bsecond TEXT NOT NULL\x0A);\""
    # echo an(Baa)
    # echo an(Baa)
    # echo an(Baa)
    # echo csv(Baa, true)
    # echo csv(Baa, true)
    # echo csv(Baa, true)