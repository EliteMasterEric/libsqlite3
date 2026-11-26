package cases;

import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import utest.Assert;
import utest.Test;

typedef PersonRecord =
{
  var name:String;
  var age:Int;
}

class TestBindObject extends Test
{
  var db:SQLiteDatabase;

  function setup()
  {
    db = SQLite.open(":memory:");
  }

  function teardown()
  {
    db.close();
  }

  function testEveryPrefix()
  {
    var row = db.prepare("SELECT :name AS name, @age AS age, $score AS score, :none IS NULL AS none").bindObject({
      name: "Bob",
      age: 25,
      score: 1.5,
      none: null
    }).executeQuery().next();
    Assert.equals("Bob", row.name);
    Assert.equals(25, row.age);
    Assert.equals(1.5, row.score);
    Assert.equals(1, row.none);
  }

  function testTypedRecord()
  {
    db.exec("CREATE TABLE Person (name TEXT, age INTEGER)");
    var insert = db.prepare("INSERT INTO Person (name, age) VALUES (:name, :age)");
    var people:Array<PersonRecord> = [
      {
        name: "Alice",
        age: 30
      },
      {
        name: "Bob",
        age: 25
      }
    ];
    for (person in people)
    {
      insert.reset().bindObject(person).executeStatement();
    }
    var row = db.prepare("SELECT count(*) AS n, sum(age) AS total FROM Person").executeQuery().next();
    Assert.equals(2, row.n);
    Assert.equals(55, row.total);
  }

  function testRepeatedName()
  {
    var row = db.prepare("SELECT :x AS a, :x * 2 AS b").bindObject({
      x: 4
    }).executeQuery().next();
    Assert.equals(4, row.a);
    Assert.equals(8, row.b);
  }

  function testNoParameters()
  {
    var row = db.prepare("SELECT 1 AS one").bindObject({
    }).executeQuery().next();
    Assert.equals(1, row.one);
  }

  function testMissingFieldThrowsRange()
  {
    var stmt = db.prepare("SELECT :a, :b");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindObject({
      a: 1
    }))?.code);
  }

  function testExtraFieldThrowsRange()
  {
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindObject({
      a: 1,
      b: 2
    }))?.code);
  }

  function testPositionalParameterThrowsRange()
  {
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> db.prepare("SELECT :a, ?").bindObject({
      a: 1
    }))?.code);
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> db.prepare("SELECT ?1").bindObject({
    }))?.code);
  }

  function testSameNameWithDifferentPrefixesThrowsMisuse()
  {
    var stmt = db.prepare("SELECT :a, @a");
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindObject({
      a: 1
    }))?.code);
  }

  function testNotAnObjectThrowsMisuse()
  {
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindObject(null))?.code);
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindObject([1]))?.code);
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindObject("a"))?.code);
  }

  function testEmojiField()
  {
    // Matched through SQLite, since hxcpp Map and field lookups of equal non-ASCII strings can fail.
    var fields:Dynamic = {};
    Reflect.setField(fields, "😀", 1);
    var row = db.prepare("SELECT :😀 AS a").bindObject(fields).executeQuery().next();
    Assert.equals(1, row.a);
  }

  function testErrorBindsNothing()
  {
    var stmt = db.prepare("SELECT :a AS a, :b AS b").bindObject({
      a: 1,
      b: 2
    });
    // An unsupported value type, a missing field and an extra field.
    catchError(() -> stmt.bindObject({
      a: 10,
      b: [20]
    }));
    catchError(() -> stmt.bindObject({
      a: 10
    }));
    catchError(() -> stmt.bindObject({
      a: 10,
      b: 20,
      c: 30
    }));
    var row = stmt.executeQuery().next();
    Assert.equals(1, row.a);
    Assert.equals(2, row.b);
  }

  static function catchError(action:() -> Void, ?pos:PosInfos):Null<SQLiteException>
  {
    try
    {
      action();
    }
    catch (e:SQLiteException)
    {
      return e;
    }
    Assert.fail("Expected an SQLiteException", pos);
    return null;
  }
}
