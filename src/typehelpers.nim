import macros
type
  TyKind* = enum
    TyUnsupported
    TyString
    TyInt
    TyFloat
    TyTuple
    TyObj
    TyRef

proc gType*(ty: NimNode): tuple[kind: TyKind, ty: NimNode] =
  # echo "VVVVVVVVVV"
  # # echo repr $ty
  # echo treeRepr(ty.getImpl())
  # echo "--------"
  # echo treeRepr(ty.getTypeImpl())
  # echo "========="
  # echo treeRepr(ty.getType())
  # echo "########"
  # echo ty.getTypeImpl().kind

  # echo ty.getImp().kind
  if ty.kind == nnkSym and ty.getImpl().kind == nnkTypeDef:
    ## unpack the type (object and tuple) and call again
    # echo "---->nnkTypeDef ", repr ty.getImpl()
    return ty.getImpl()[2].gType()
  elif ty.getTypeImpl().kind == nnkSym:
    if ty.getTypeImpl().strVal() == "string": return (TyString, ty.getTypeImpl())
    elif ty.getTypeImpl().strVal() == "int": return (TyInt, ty.getTypeImpl())
    elif ty.getTypeImpl().strVal() == "float": return (TyFloat, ty.getTypeImpl())
  elif ty.getTypeImpl().kind == nnkObjectTy: return (TyObj, ty.getTypeImpl())
  elif ty.getTypeImpl().kind == nnkRefTy: return (TyRef, ty.getTypeImpl())
  elif ty.getTypeImpl().kind == nnkTupleTy: return (TyTuple, ty.getTypeImpl())
  elif ty.getTypeImpl().kind == nnkBracketExpr: # and ty.getType().kind == nnkBracketExpr:
    ## unpack the type (int) and call again
    return ty.getTypeImpl()[1].gtype()
    discard
  else: return (TyUnsupported, newNimNode(nnkNone))


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

  # echo foo2(foo) # == TyObj