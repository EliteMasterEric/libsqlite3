package cases;

import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import utest.Assert;
import utest.Test;

class TestBindJson extends Test
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

  function testObjectIsReadableBySqlite()
  {
    var row = db.prepare("SELECT json_valid(?1) AS valid, json_extract(?1, '$.name') AS name, json_extract(?1, '$.tags[1]') AS tag").bindJson(1, {
      name: "Alice",
      tags: ["a", "b"]
    }).executeQuery().next();
    Assert.equals(1, row.valid);
    Assert.equals("Alice", row.name);
    Assert.equals("b", row.tag);
  }

  function testRoundTrip()
  {
    db.exec("CREATE TABLE Doc (data TEXT)");
    db.prepare("INSERT INTO Doc (data) VALUES (?)").bindJson(1, {
      n: 3,
      list: [1, 2, 3],
      nested: {
        ok: true
      }
    }).executeStatement();
    var data:String = db.prepare("SELECT data FROM Doc").executeQuery().next().data;
    var parsed:Dynamic = haxe.Json.parse(data);
    Assert.equals(3, parsed.n);
    Assert.equals(3, parsed.list.length);
    Assert.isTrue(parsed.nested.ok);
  }

  function testQueryStoredJson()
  {
    db.exec("CREATE TABLE Person (data TEXT)");
    var insert = db.prepare("INSERT INTO Person (data) VALUES (?)");
    insert.bindJson(1, {
      name: "Alice",
      age: 30
    }).executeStatement();
    insert.reset().bindJson(1, {
      name: "Bob",
      age: 25
    }).executeStatement();
    var row = db.prepare("SELECT data ->> '$.name' AS name FROM Person WHERE data ->> '$.age' < ?").bindInt(1, 28).executeQuery().next();
    Assert.equals("Bob", row.name);
  }

  function testScalars()
  {
    var row = db
      .prepare("SELECT ?1 AS s, json_type(?1) AS sType, ?2 AS n, ?3 AS b")
      .bindJson(1, "text")
      .bindJson(2, 1.5)
      .bindJson(3, false)
      .executeQuery()
      .next();
    Assert.equals('"text"', row.s);
    Assert.equals("text", row.sType);
    Assert.equals("1.5", row.n);
    Assert.equals("false", row.b);
  }

  function testNullBindsNull()
  {
    var row = db.prepare("SELECT ? IS NULL AS boundNull").bindJson(1, null).executeQuery().next();
    Assert.equals(1, row.boundNull);
  }

  function testEscapedCharacters()
  {
    var value = 'quote " backslash \\ newline \n tab \t unicode é';
    var row = db.prepare("SELECT json_valid(?1) AS valid, json_extract(?1, '$.s') AS s").bindJson(1, {
      s: value
    }).executeQuery().next();
    Assert.equals(1, row.valid);
    Assert.equals(value, row.s);
  }

  function testControlCharacter()
  {
    // haxe.Json.stringify writes most control characters unescaped; SQLite must still read them back.
    var value = "a\x01b";
    var row = db.prepare("SELECT json_extract(?1, '$.s') AS s").bindJson(1, {
      s: value
    }).executeQuery().next();
    Assert.equals(value, row.s);
  }

  function testNonFiniteFloatsBecomeNull()
  {
    // JSON has no NaN or Infinity, so haxe.Json.stringify writes them as null, like JavaScript's JSON.stringify.
    var row = db
      .prepare("SELECT json_valid(?1) AS valid, json_type(?1, '$.nan') AS nan, json_type(?1, '$.inf') AS inf, json_type(?1, '$.negInf') AS negInf")
      .bindJson(1, {
        nan: Math.NaN,
        inf: Math.POSITIVE_INFINITY,
        negInf: Math.NEGATIVE_INFINITY
      })
      .executeQuery()
      .next();
    Assert.equals(1, row.valid);
    Assert.equals("null", row.nan);
    Assert.equals("null", row.inf);
    Assert.equals("null", row.negInf);
  }

  function testBoundJsonNeedsJsonFunction()
  {
    // Bound text isn't marked as JSON, so json_object() quotes it unless it is wrapped in json().
    var row = db.prepare("SELECT json_object('a', ?1) AS plain, json_object('a', json(?1)) AS wrapped").bindJson(1, [1, 2]).executeQuery().next();
    Assert.equals('{"a":"[1,2]"}', row.plain);
    Assert.equals('{"a":[1,2]}', row.wrapped);
  }

  function testBindJsonByName()
  {
    var row = db.prepare("SELECT json_extract(:doc, '$.x') AS x").bindJsonByName(":doc", {
      x: 7
    }).executeQuery().next();
    Assert.equals(7, row.x);
  }

  function testBindJsonByNameUnknownThrowsRange()
  {
    var stmt = db.prepare("SELECT :doc");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindJsonByName(":other", {
    }))?.code);
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
