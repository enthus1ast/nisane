# TODO
# DONE bool
# DONE ref object
# TODO to macro "_" should skip
# Beef: Depending on what you want you could use disruptek's assume package which has typeit allowing you to iterate fields of objects
# Beef: https://github.com/disruptek/assume/blob/master/tests/typeit.nim#L102-L199

import macros, strutils, strformat
import typehelpers

proc toString*(str: string): string = str
# proc toString*(str: ref string): string = str[]
proc toFloat*(str: string): float {.inline.} = parseFloat(str)
proc toInt*(str: string): int {.inline.} = parseInt(str)
proc toBool*(str: string): bool {.inline.} = parseBool(str)
proc toChar*(str: string): char {.inline.} = str[0]

template defaultValue*(def: string | int | float) {.pragma.} ## does not work yet :/
# template defaultValue*() {.pragma.}

macro to*(se: untyped, tys: varargs[typed]): typed =
  ## a generic seq/openarray unpacker.
  runnableExamples:
    type Obj = object
      aa: string
      bb: int
      cc: bool
    var se = ["foo", "1", "true"]
    var obj = Obj()
    se.to(obj)
    assert obj.aa == "foo"
    assert obj.bb == 1
    assert obj.cc == true

  echo "to se:", repr se
  result = newStmtList()

  var seqidx = 0
  for ty in tys:

    # echo "####"
    # echo treeRepr(ty.getTypeImpl())
    # echo "end####"
    # echo $ty.gType & "##############################"
    let (kind, tyy) = ty.gType
    case kind
    of TyString:
      # echo "BT: string"
      let ex = $ty & " = "  & (repr se)  & "[" & $seqidx  & "]"  & ".toString"
      result.add parseStmt(ex)
      seqidx.inc
    of TyInt:
      # echo "BT: int"
      let ex = $ty & " = "  & (repr se)  & "[" & $seqidx  & "]"  & ".toInt"
      result.add parseStmt(ex)
      seqidx.inc
    of TyBool:
      # echo "BT: int"
      let ex = $ty & " = "  & (repr se)  & "[" & $seqidx  & "]"  & ".toBool"
      result.add parseStmt(ex)
      seqidx.inc
    of TyFloat:
      # echo "BT: float"
      let ex = $ty & " = "  & (repr se)  & "[" & $seqidx  & "]"  & ".toFloat"
      result.add parseStmt(ex)
      seqidx.inc
    of TyObj:
      # echo "OBJECT TYPE"
      # echo treeRepr(ty.getType())
      for idx, el in ty.getTypeImpl[2].pairs:
        echo idx, " ",  repr el
        let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & (repr se)  & "[" & $seqidx  & "]" & ".to" & el[1].strval.capitalizeAscii
        result.add parseStmt(ex)
        seqidx.inc
    of TyRefObj:
      for idx, el in tyy[2][2].pairs:
        echo idx, " ",  repr el
        let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & (repr se)  & "[" & $seqidx  & "]" & ".to" & el[1].strval.capitalizeAscii
        result.add parseStmt(ex)
        seqidx.inc
    of TyRef:
      echo "REF OBJECT TYPE not implemented!"
      echo "https://github.com/status-im/nim-stew/blob/8a405309c660d1ceca8d505e340850e5b18f83a8/stew/shims/macros.nim#L184"
      echo "####"
      # echo repr ty.getType()[1]
      # echo treeRepr(ty.getType().getType())
      # echo treeRepr(ty.symToIdent) #.getType().getType().getTypeImpl())
      # echo repr ty.getTypeImpl().getTypeImpl().getTypeImpl() #getImplTransformed()
      echo "end####"
    of TyTuple:
      # echo "tuple"
      for idx, el in ty.getTypeImpl.pairs:
        # echo "TU", idx, " ",  repr el
        let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & (repr se)  & "[" & $seqidx  & "]" & ".to" & el[1].strval.capitalizeAscii
        result.add parseStmt(ex)
        seqidx.inc
    of TyUnsupported:
      echo "Unsupported!"

proc mapToSqlType*(nimType: string): string =
  ## Maps nim type to sql type.
  case nimType.toLowerAscii()
  of "int": return "INTEGER"
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
  let tyName = $ty

  var sq = fmt"CREATE TABLE IF NOT EXISTS {tyName}(" & "\n"
  var lines: seq[string] = @[]
  let (kind, tyy) = gType(ty)
  case kind
  of TyObj:
    for idx, el in tyy[2].pairs:
      echo treeRepr el
      echo idx, " ",  repr el
      let name = toStrLit(el[0]).strval
      let nimType = el[1].strval
      let sqlType = nimType.mapToSqlType()
      var ex = fmt"{name} {sqlType} NOT NULL"
      # echo "HAS CUSTOM PRAGMA:", hasCustomPragma(el[0][1], defaultValue)
      # echo "EX  ", ex
      lines.add ex
  else:
    echo "Unsupported"

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
  let tyName = $ty
  var sq = fmt"INSERT INTO {tyName}("
  var lines: seq[string] = @[]
  let (kind, tyy) = gType(ty)
  case kind
  of TyObj:
    for idx, el in tyy[2].pairs:
      lines.add $el[0]
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
  else:
    echo "Unsupported"
  return newLit(sq)


when isMainModule:
  type
    FooBaa = object {.defaultValue: "FAA".}
      # id: int
      first {.defaultValue: "ff".}: string
      second: string
      third {.defaultValue: 0.1337.}: float
      forth: int

  ## does not work
  # var fb = FooBaa()
  # echo fb.hasCustomPragma(defaultValue)
  # echo fb.first.hasCustomPragma(defaultValue)


when isMainModule and true:
  import print
  import db_sqlite

  type
    Foo = object
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

  var se = @["foo", "baa", "13.37", "123"]

  var db = open(":memory:", "", "", "")
  db.exec(sql ct(Foo))
  db.exec(sql ct(Foo2))

  # db.exec(sql"""CREATE TABLE IF NOT EXISTS Baa(
  #   id    INTEGER PRIMARY KEY,
  #         first   TEXT    NOT NULL        DEFAULT '',
  #         second  TEXT    NOT NULL        DEFAULT '',
  #         third   REAL    NOT NULL        DEFAULT 0.0,
  #         forth   INTEGER NOT NULL        DEFAULT 0
  # );""")

  # db.exec(sql"INSERT INTO Foo (first, second, third, forth) VALUES (?, ?, ?, ?)", "first", "second", "13.37", "123")
  for idx in 0..10:
    db.exec(sql ci(Foo), $idx & "first", "second", "13.37", "123")
    db.exec(sql ci(Foo2), $idx & "first", "second", "13.37", "123")

    db.exec(sql ci(Foo), $idx & "adfsadfff", "fffasdf", "13.37", "123")
    db.exec(sql ci(Foo2), $idx & "fasdfwefew", "fwef32fwef3", "13.37", "123")

  for row in db.getAllRows(sql"select * from Foo, Foo2 where Foo.id = Foo2.id"):
    echo row
    var idFoo: int = -1
    var foo: Foo = Foo()

    expandMacros:
      to(row, idFoo, foo)
    echo idFoo
    # print idFoo, foo, idBaa, baa

  var idxA: int = -1
  var idxB: int = -1
  type AB = object
    aa: int
    bb: int
  for row in db.getAllRows(sql"select count(Foo.id), count(Foo2.id) * 2  from Foo, Foo2 where Foo.second = ? and Foo2.second = ? ", "fffasdf", "fwef32fwef3"):
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

  # import print
  # block:
  #   var se = @["1", "sss", "33.33", "123" , "first", "second", "13.37", "123", "11", "22", "33", "123", "first", "second", "13.37", "123",]
  #   var idx = 0
  #   var ss = ""
  #   var ff = 13.37
  #   var obj = Foo()
  #   var obj2 = Foo()

  #   var robj = RFoo()
  #   var tup: tuple[a, b, c: int]
  #     # to3(se, idx, ss, ff, obj, robj, tup)
  #   # expandMacros:
  #   #   to3(se, idx, ss, ff, obj, tup)
  #   expandMacros:
  #     to(se, idx, ss, ff, obj, tup, obj2)

  #   # to3(se, idx, ss, ff, obj, tup)
  #   se.to(idx, ss, ff, obj, tup, obj2)
  #   print idx, ss, ff, obj, tup, obj2

  # # ##



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