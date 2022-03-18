import macros, tables

import """C:\Users\david\projects\nisane\src\typehelpers.nim"""

template default(str: string) {.pragma.}
template default(str: int) {.pragma.}
template default(str: float) {.pragma.}
template rax(str: string) {.pragma.}
template iii(ii: int) {.pragma.}
template tablename*(name: string) {.pragma.} ## Overwrite the tablename
template id(idname: string = "id") {.pragma.} ## adds the id

type
  TyPragmaKind = enum
    TyPragmaInt
    TyPragmaFloat
    TyPragmaString
  TyPragma = object
    name*: string
    case kind*: TyPragmaKind
    of TyPragmaInt: intVal*: int
    of TyPragmaFloat: floatVal*: float
    of TyPragmaString: strVal*: string



type
  Foo {.default: "foo", rax: "hihi", iii: 123, id: "myid".} = object
    id {.default: 6616.}: int
    baa {.default: "asdf".}: string

proc hasPragmaDef(ty: NimNode): bool =
  if ty.getImpl.kind == nnkTypeDef or ty.getImpl.kind == nnkIdentDefs:
    if ty.getImpl[0].kind == nnkPragmaExpr:
      return true
  return false


proc typePragma*(ty: NimNode): Table[string, TyPragma] =
  # result = newStmtList()
  echo treeRepr ty.getImpl
  var tp: Table[string, TyPragma]
  if ty.hasPragmaDef():
    for pr in ty.getImpl[0][1]:
      let prname = pr[0]
      let prval = pr[1]
      case pr[1].kind
      of nnkIntLit:
        tp[$prname] = TyPragma(
          kind: TyPragmaInt,
          name: $prname,
          intVal: prval.intVal.int
        )
      of nnkStrLit:
        tp[$prname] = TyPragma(
          kind: TyPragmaString,
          name: $prname,
          strVal: prval.strVal
        )
      of nnkFloatLit:
        tp[$prname] = TyPragma(
          kind: TyPragmaFLoat,
          name: $prname,
          floatVal: prval.floatVal
        )
      else:
        echo "UNK"
      echo "prname: ", repr prname, " prval:", repr prval
  return tp

macro dummy(ty: typed) =
  echo typePragma(ty)

# macro attribPragma(ty: typed) =
#   echo ty.hasPragmaDef()
  # let (kind, tyy) = gType(ty)
  # case kind
  # of TyObj, TyTuple, TyRefObj:
  #   echo kind
  #   for idx, el in ty.pairs:
  #     echo idx, el
      # echo el.hasPragmaDef()
      # echo repr el
  # else:
  #   echo "Unsupported"
  #   return
  # for tu in ty.gType():
    # echo tu.ty.hasPragmaDef()
  # let tyi = ty.getImpl
  # if tyi.kind == nnkTypeDef:
  #   echo "type def"
  #   if tyi[0].kind == nnkPragmaExpr:
  #     echo "pragma expr"

macro dummy2(ty: typed) =
  echo "dummy2"
  let (kind, tyy) = gType(ty)
  case kind
  of TyObj, TyTuple, TyRefObj:
    echo treeRepr ty.getImpl
    # echo treeRepr ty.getImpl
    # for idx, el in ty.getImpl.pairs:
    #   echo idx, " ", repr el, " "
    #   echo treeRepr el
    #   echo hasPragmaDef(el)
    #   # echo repr attribPragma(el)
    #   # lines.add $el[0]
  else:
    discard

when isMainModule:
  echo "foo"
  # dummy(Foo)ech
  dummy2(Foo)
  # attribPragma(Foo)
