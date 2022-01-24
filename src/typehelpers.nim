import macros
type
  TyKind* = enum
    TyUnsupported
    TyString
    TyInt
    TyBool
    TyFloat
    TyTuple
    TyObj
    TyRef
    TyRefObj



########################################
# beef: for ty ref
# import std/macros

# macro doThing(a: typed) =
#   var impl = a.getTypeImpl
#   if impl.kind == nnkBracketExpr and impl[0].eqIdent"typedesc":
#     impl = a.getImpl
#   elif impl.kind == nnkRefTy and impl[0].kind == nnkSym:
#     impl = impl[0].getImpl
#   echo impl.treeRepr

# type
#   A = ref object
#     a, b: int
#     c: string
#     d: A
# doThing(A)
# doThing(A())
# {.error: "Let's see".}
###############################


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
    elif ty.getTypeImpl().strVal() == "bool": return (TyBool, ty.getTypeImpl())
    elif ty.getTypeImpl().strVal() == "float": return (TyFloat, ty.getTypeImpl())
  elif ty.getTypeImpl().kind == nnkObjectTy: return (TyObj, ty.getTypeImpl()[2])
  # elif ty.getTypeImpl().kind == nnkRefTy: return (TyRef, ty.getTypeImpl())
  elif ty.getTypeImpl().kind == nnkTupleTy: return (TyTuple, ty.getTypeImpl())
  elif ty.getTypeImpl().kind == nnkBracketExpr: # and ty.getType().kind == nnkBracketExpr:
    ## unpack the type (int) and call again
    return ty.getTypeImpl()[1].gtype()
  elif ty.getTypeImpl().kind == nnkRefTy and ty.getTypeImpl()[0].kind == nnkSym:
    ## Ref obj # TODO this could also be other ref types!
    # if ty.getTypeImpl[0].getType.kind == nnkSym:
    #   if ty.getTypeImpl[0].getType.strval == "string":
    #     return (TyString, ty.getTypeImpl())
    return (TyRefObj, ty.getTypeImpl[0].getImpl[2][2]) # [2])

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
  # echo foo1(robj).kind
  # echo foo1(Robj).kind
  assert TyRefObj == foo1(Robj).kind
  assert TyRefObj == foo1(robj).kind


  # echo foo2(foo) # == TyObj