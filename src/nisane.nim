import macros, strutils

template toString*(str: string): string = str
proc toFloat*(str: string): float {.inline.} = parseFloat(str)
proc toInt*(str: string): int {.inline.} = parseInt(str)
proc toChar*(str: string): char {.inline.} = str[0]

macro to(se: untyped, tys: varargs[typed]): typed =
    result = newStmtList()

    var seqidx = 0
    for ty in tys:

      # echo "####"
      # echo treeRepr(ty.getTypeImpl())
      # echo "end####"

      if ty.getTypeImpl().kind == nnkSym:
        # echo "BASIC TYPE:"

        if ty.getTypeImpl().strVal() == "string":
          # echo "BT: string"
          let ex = $ty & " = "  & se.strval  & "[" & $seqidx  & "]"  & ".toString"
          result.add parseStmt(ex)
          seqidx.inc

        elif ty.getTypeImpl().strVal() == "int":
          # echo "BT: int"
          let ex = $ty & " = "  & se.strval  & "[" & $seqidx  & "]"  & ".toInt"
          result.add parseStmt(ex)
          seqidx.inc

        elif ty.getTypeImpl().strVal() == "float":
          # echo "BT: float"
          let ex = $ty & " = "  & se.strval  & "[" & $seqidx  & "]"  & ".toFloat"
          result.add parseStmt(ex)
          seqidx.inc

      elif ty.getTypeImpl().kind == nnkObjectTy:
        # echo "OBJECT TYPE"
        echo treeRepr(ty.getType())
        for idx, el in ty.getTypeImpl[2].pairs:
          echo idx, " ",  repr el
          let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & se.strval  & "[" & $seqidx  & "]" & ".to" & el[1].strval.capitalizeAscii
          result.add parseStmt(ex)
          seqidx.inc

      elif ty.getTypeImpl().kind == nnkRefTy:
        echo "REF OBJECT TYPE not implemented!"
        echo "https://github.com/status-im/nim-stew/blob/8a405309c660d1ceca8d505e340850e5b18f83a8/stew/shims/macros.nim#L184"
        echo "####"
        # echo repr ty.getType()[1]
        # echo treeRepr(ty.getType().getType())
        # echo treeRepr(ty.symToIdent) #.getType().getType().getTypeImpl())
        # echo repr ty.getTypeImpl().getTypeImpl().getTypeImpl() #getImplTransformed()
        echo "end####"

      elif ty.getTypeImpl().kind == nnkTupleTy:
        # echo "tuple"
        for idx, el in ty.getTypeImpl.pairs:
          # echo "TU", idx, " ",  repr el
          let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & se.strval  & "[" & $seqidx  & "]" & ".to" & el[1].strval.capitalizeAscii
          result.add parseStmt(ex)
          seqidx.inc


when isMainModule and true:

  # ##
  import db_sqlite
  import gatabase
  include gatabase/[sugar, templates]

  import macros, strutils


  # # macro to(se: seq[string], ty: typed) =
  # macro to(se: untyped, ty: typed) =
  #   discard
  #   # for ss in se:
  #   #   echo ss
  #   echo repr ty
  #   for idx, el in ty.getImpl[2][2].pairs:
  #     echo idx, " ",  repr el
  #     echo $ty, ".", toStrLit(el[0]), " = " , repr se , "[", idx ,"]", ".to", el[1]




  type
    Foo = object
      id: int
      first: string
      second: string
      third: float
      forth: int

  # echo createTable "Foo":
  #   Foo

  # let myTable = createTable "Foo": [
  #   "first"  := "",
  #   "second"  := "",
  #   "third" := 0.0,
  #   "forth" := 0
  # ]

  let myTable = createTable "Foo": [
    "first"  := string,
    "second"  := string,
    "third" := float,
    "forth" := int,
  ]

  # let myTable = createTable "kitten": [
  #   "age"  := 1,
  #   "sex"  := 'f',
  #   "name" := "fluffy",
  #   "rank" := 3.14,
  # ]

  # var foo = Foo()
  var se = @["foo", "baa", "13.37", "123"]
  # to(se, Foo)

  macro to2(se: untyped, ty: typed): typed =
    result = newStmtList()
    for idx, el in ty.getTypeImpl[2].pairs:
      echo idx, " ",  repr el
      let ex = $ty & "." & toStrLit(el[0]).strval & " = "  & se.strval  & "[" & $idx  & "]" & ".to" & el[1].strval.capitalizeAscii
      result.add parseStmt(ex)



  # var foo = Foo()
  # to2(se, foo)
  # echo foo

  var db = open(":memory:", "", "", "")
  echo myTable.string
  # db.exec(myTable)
  db.exec(sql"""CREATE TABLE IF NOT EXISTS Foo(
    id    INTEGER PRIMARY KEY,
          first   TEXT    NOT NULL        DEFAULT '',
          second  TEXT    NOT NULL        DEFAULT '',
          third   REAL    NOT NULL        DEFAULT 0.0,
          forth   INTEGER NOT NULL        DEFAULT 0
  );""")

  db.exec(sql"""CREATE TABLE IF NOT EXISTS Baa(
    id    INTEGER PRIMARY KEY,
          first   TEXT    NOT NULL        DEFAULT '',
          second  TEXT    NOT NULL        DEFAULT '',
          third   REAL    NOT NULL        DEFAULT 0.0,
          forth   INTEGER NOT NULL        DEFAULT 0
  );""")

  db.exec(sql"INSERT INTO Foo (first, second, third, forth) VALUES (?, ?, ?, ?)", "first", "second", "13.37", "123")
  db.exec(sql"INSERT INTO Baa (first, second, third, forth) VALUES (?, ?, ?, ?)", "first", "second", "13.37", "123")

  db.exec(sql"INSERT INTO Foo (first, second, third, forth) VALUES (?, ?, ?, ?)", "adfsadfff", "fffasdf", "13.37", "123")
  db.exec(sql"INSERT INTO Baa (first, second, third, forth) VALUES (?, ?, ?, ?)", "fasdfwefew", "fwef32fwef3", "13.37", "123")

  echo db.getAllRows(sql"select * from Foo, Baa where Foo.id = Baa.id")

  # type
  #   RFoo = ref object
  #     ii: int

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





when isMainModule and false:
  import print
  import unittest

  type
    Foo2 = object
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
      var obj: Foo2
      row.to(id, obj)
      check id == 1
      check obj.first == "first"
      check obj.second == "second"
      check obj.third == 13.37
      check obj.fourth == 123
    test "id + Obj + id2 + Obj2":
      var id: int
      var obj: Foo2
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



