import strutils, macros

proc unpackValue*(str: string, val: var string) = val = str
proc unpackValue*(str: string, val: var int)    = val = parseInt(str)
proc unpackValue*(str: string, val: var float)  = val = parseFloat(str)
proc unpackValue*(str: string, val: var bool)   = val = parseBool(str)
proc unpackValue*(str: string, val: var char)   = val = str[0]


proc unpackItem*[S](se: S, idx: var int, target: var any) =
  # If target is a primitive type handled by our hooks
  when compiles(unpackValue(se[idx], target)):
    unpackValue(se[idx], target)
    idx.inc
  # If target is an object or a tuple, iterate its fields
  elif compiles(for k, v in fieldPairs(target): discard):
    for name, field in fieldPairs(target):
      unpackItem(se, idx, field)
  # If target is a ref object, initialize if nil, then unpack its contents
  elif typeof(target) is ref:
    if target.isNil:
      target = new(typeof(target))
    unpackItem(se, idx, target[])
  else:
    {.error: "Unsupported type for unpacking: " & $typeof(target).}

# Orchestration helpers for 'to' syntax
template unpackArg[S](se: S, idx: var int, arg: typeof(nil)) =                                         
  idx.inc

template unpackArg[S](se: S, idx: var int, arg: var any) =
  unpackItem(se, idx, arg)

macro to*(se: openArray[string], args: varargs[untyped]): untyped =
  result = newStmtList()
  let idxVar = genSym(nskVar, "unpackIdx")
  result.add newVarStmt(idxVar, newLit(0))
  for arg in args:
    if arg.kind == nnkNilLit:
      result.add quote do: unpackArg(`se`, `idxVar`, nil)
    else:
      result.add quote do: unpackArg(`se`, `idxVar`, `arg`)


when isMainModule:
  import unittest

# ==========================================
# Test Suite
# ==========================================

# ==========================================
# Custom Type Test Setup
# ==========================================
type
  MyCustom = object
    x: int
    y: int

  BasicObj = object
    aa: string
    bb: int
    cc: bool

  NestedObj = object
    id: int
    sub: BasicObj

  RefObj = ref object
    val: float
    name: string

  MyRootObj = ref object of RootObj
    id: int
    name: string

  MyChildAA = ref object of MyRootObj
    aa: string
    aa2: string

  MyChildBB = ref object of MyRootObj
    bb: string
    bb2: string


# Custom unpack hook implementation
proc unpackValue*(str: string, val: var MyCustom) =
  let parts = str.split(":")
  val.x = parts[0].parseInt
  val.y = parts[1].parseInt

suite "Nisane unpackItem Tests":

  test "Unpack standalone primitives":

    let data = @["1337", "3.14", "true", "X"]
    var idx = 0
    
    var i: int
    var f: float
    var b: bool
    var c: char
    
    unpackItem(data, idx, i)
    unpackItem(data, idx, f)
    unpackItem(data, idx, b)
    unpackItem(data, idx, c)

    check i == 1337
    check f == 3.14
    check b == true
    check c == 'X'
    check idx == 4

  test "Unpack flat object structures":
    let data = @["foo", "42", "false"]
    var idx = 0
    var obj: BasicObj
    
    unpackItem(data, idx, obj)
    
    check obj.aa == "foo"
    check obj.bb == 42
    check obj.cc == false
    check idx == 3

  test "Unpack tuple types":
    let data = @["hello", "99"]
    var idx = 0
    var tup: tuple[msg: string, code: int]
    
    unpackItem(data, idx, tup)
    
    check tup.msg == "hello"
    check tup.code == 99
    check idx == 2

  test "Unpack nested structures (Object inside Object)":
    let data = @["100", "inner_string", "777", "true"]
    var idx = 0
    var container: NestedObj
    
    unpackItem(data, idx, container)
    
    check container.id == 100
    check container.sub.aa == "inner_string"
    check container.sub.bb == 777
    check container.sub.cc == true
    check idx == 4

  test "Unpack ref objects (Auto-instantiation)":
    let data = @["0.5", "Ghost"]
    var idx = 0
    var robj: RefObj # starts as nil
    
    unpackItem(data, idx, robj)
    
    check robj != nil
    check robj.val == 0.5
    check robj.name == "Ghost"
    check idx == 2
  
  test "Unpack ref objects (already instantiated)":
    let data = @["0.5", "Ghost"]
    var idx = 0
    var robj: RefObj = RefObj(val: -1, name: "changeMe") 
    
    unpackItem(data, idx, robj)
    
    check robj != nil
    check robj.val == 0.5
    check robj.name == "Ghost"
    check idx == 2


  test "Custom hook resolution":
    let data = @["123:456"]
    var idx = 0
    var custom: MyCustom
    
    unpackItem(data, idx, custom)
    
    check custom.x == 123
    check custom.y == 456
    check idx == 1

  test "Macro integration with sequential skips via nil":
    let data = @["1337", "skip_this", "foo", "1", "true"]
    
    var id: int
    var obj: BasicObj
    
    # Leverages our macro orchestration layer wrapper
    data.to(id, nil, obj)
    
    check id == 1337
    check obj.aa == "foo"
    check obj.bb == 1
    check obj.cc == true



  test "a":
    let data = @["1337", "skip_this", "foo", "1", "true"]

    var id: int
    var str: string
    expandMacros:
      data.to(id, nil , str)
    
    check id == 1337
    check str == "foo"


    data.to(id, nil , str)
    
    check id == 1337
    check str == "foo"


  test "b":
    ## There is a catch with derived objects.
    ## The childrens data must come first!
    let data = @["aa", "aa2", "1338", "37", "MyName"]
    var myroot: MyRootObj
    data.to(nil, nil, myroot)
    check myroot.id == 1338

    var myChildAA = MyChildAA()
    data.to(myChildAA)
    check myChildAA.aa == "aa"
    check myChildAA.aa2 == "aa2"
    check myChildAA.id == 1338
    # expandMacros:
    #   data.to(myChildAA)
    echo myChildAA[]

    var myChildBB = MyChildBB()
    expandMacros:
      data.to(myChildBB)
    echo myChildBB[]

    # check myChildObAge.id == 1338
    # check myChildObAge.id == 1338

