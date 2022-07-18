import std/[macros, strutils]

type
  TyKind* = enum
    TyUnsupported
    TyString = "string"
    TyInt = "int"
    TyBool = "bool"
    TyFloat = "float"
    TyInt64 = "int64"
    TyTuple
    TyObj
    TyRefObj
    TyRefObjInherited

proc isInherited*(typeImpl: NimNode): bool =
  return typeImpl[0].getImpl()[2][1].kind == nnkOfInherit

proc getBaseClassName*(ty: NimNode): NimNode =
  return ty.getTypeImpl[0].getImpl()[2][1][0].getImpl()[0]

proc getBaseClass*(ty: NimNode): NimNode =
  return ty.getTypeImpl[0].getImpl()[2][1][0].getImpl()


proc gType*(ty: NimNode): tuple[kind: TyKind, ty: NimNode] =
  if ty.kind == nnkSym and ty.getImpl().kind == nnkTypeDef:
    ## unpack the type (object and tuple) and call again
    return ty.getImpl()[2].gType()

  let typeImpl: NimNode = ty.getTypeImpl()
  case typeImpl.kind:
    of nnkSym:
      let typeTyKind: TyKind = parseEnum[TyKind](typeImpl.strVal())
      return (typeTyKind, typeImpl)

    of nnkObjectTy:
      return (TyObj, typeImpl[2])

    of nnkTupleTy:
      return (TyTuple, typeImpl)

    of nnkBracketExpr:
      ## unpack the type (int) and call again
      return typeImpl[1].gtype()

    of nnkRefTy:
      if typeImpl[0].kind == nnkSym:
        if typeImpl.isInherited():
          return (TyRefObjInherited, ty.getTypeImpl[0].getImpl[2][2]) # [2])
        else:
          return (TyRefObj, ty.getTypeImpl[0].getImpl[2][2]) # [2])
      else:
        return (TyUnsupported, newNimNode(nnkNone))

    else:
      return (TyUnsupported, newNimNode(nnkNone))


when isMainModule:
  type
    Foo = object
      ii: int

  macro foo1(ty: typed): tuple[kind: TyKind, ty: NimNode] =
    return newLit(ty.gType())

  # macro foo2(ty: varargs[typed]): TyKind =
  #   return newLit(ty[0].gType())

  var foo = Foo()
  assert TyObj == foo1(Foo).kind
  assert TyObj == foo1(foo).kind

  type TT = tuple[a, b, c: string]
  var tt: tuple[a, b, c: string]
  assert TyTuple == foo1(TT).kind
  assert TyTuple == foo1(tt).kind

  var ii: int
  assert TyInt == foo1(int).kind
  assert TyInt == foo1(ii).kind

  var ff: float
  assert TyFloat == foo1(float).kind
  assert TyFloat == foo1(ff).kind

  var ss: string
  assert TyString == foo1(string).kind
  assert TyString == foo1(ss).kind

  var bb: bool
  assert TyBool == foo1(bool).kind
  assert TyBool == foo1(bb).kind

  # type Rstr = ref string
  # var rss: Rstr
  # assert TyString == foo1(Rstr).kind
  # assert TyString == foo1(rss).kind
  # assert TyBool == foo1(bool).kind
  # assert TyBool == foo1(bb).kind

  type Robj = ref object
    ii: int
    bb: bool
  var robj: Robj
  assert TyRefObj == foo1(Robj).kind
  assert TyRefObj == foo1(robj).kind


  type
    Bobj = ref object of RootObj
      ii: int
      bb: bool
    Sobj = ref object of Bobj
  var sobj: Sobj
  assert TyRefObjInherited == foo1(Sobj).kind
  assert TyRefObjInherited == foo1(sobj).kind