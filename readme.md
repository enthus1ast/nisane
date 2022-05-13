a seq unpacker and mini `orm`

```nim
type Obj = object
  aa: string
  bb: int
  cc: bool
var se = ["1337","somethingToSkip", "foo", "1", "true"]
var id: int
var obj = Obj()
se.to(id, nil, obj)
assert obj.aa == "foo"
assert obj.bb == 1
assert obj.cc == true
```


```nim
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

var db = open(":memory:", "", "", "")

# Easy to create tables based on types.
db.exec(sql ct(Foo)) # create tables based on the types
db.exec(sql ct(Foo2)) # create tables based on the types

# Easy to insert, based on types.
for idx in 0..10:
  db.exec(sql ci(Foo), $idx & "first", "second", "13.37", "123")
  db.exec(sql ci(Foo2), $idx & "fasdfwefew", "fwef32fwef3", "13.37", "123")

# Just write any sql, then unpack the types.
for row in db.getAllRows(sql"select * from Foo, Foo2 where Foo.id = Foo2.id"):
  var foo: Foo = Foo()
  var foo2: Foo2 = Foo2()
  row.to(nil, foo, nil, foo2) # skip elements with nil (eg: table id's)
  # ... use foo and foo2
```


Unpack custom types:
```nim
import nisane, strutils

type
  MyCustom = object
    x: int
    y: int
  Obj = object
    aa: MyCustom
    bb: int
    cc: bool

# Define unpacker in the form of
# toXXX to unpack your custom types.
proc toMyCustom(str: string): MyCustom =
  let parts = str.split(":")
  result.x = parts[0].parseInt
  result.y = parts[1].parseInt

var se = ["1337","somethingToSkip", "123:456", "1", "true"]
var id: int
var obj = Obj()
se.to(id, nil, obj)
assert obj.aa.x == 123
assert obj.aa.y == 456
assert obj.bb == 1
assert obj.cc == true
```
