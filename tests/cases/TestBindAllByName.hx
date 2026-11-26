package cases;

import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import utest.Assert;
import utest.Test;

class TestBindAllByName extends Test
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

  function testBindsEveryName()
  {
    var row = db.prepare("SELECT :name AS name, @age AS age, $score AS score, :none IS NULL AS none").bindAllByName([
      ":name" => "Bob",
      "@age" => 25,
      "$score" => 1.5,
      ":none" => null
    ]).executeQuery().next();
    Assert.equals("Bob", row.name);
    Assert.equals(25, row.age);
    Assert.equals(1.5, row.score);
    Assert.equals(1, row.none);
  }

  function testRepeatedName()
  {
    var row = db.prepare("SELECT :x AS a, :x * 2 AS b").bindAllByName([":x" => 4]).executeQuery().next();
    Assert.equals(4, row.a);
    Assert.equals(8, row.b);
  }

  function testNumberedParameters()
  {
    var row = db.prepare("SELECT ?1 AS a, ?2 AS b").bindAllByName(["?1" => "one", "?2" => "two"]).executeQuery().next();
    Assert.equals("one", row.a);
    Assert.equals("two", row.b);
  }

  function testInsertAndReuse()
  {
    db.exec("CREATE TABLE Person (name TEXT, age INTEGER)");
    var insert = db.prepare("INSERT INTO Person (name, age) VALUES (:name, :age)");
    insert.bindAllByName([":name" => "Alice", ":age" => 30]).executeStatement();
    insert.reset().bindAllByName([":name" => "Bob", ":age" => 25]).executeStatement();
    var row = db.prepare("SELECT count(*) AS n, sum(age) AS total FROM Person").executeQuery().next();
    Assert.equals(2, row.n);
    Assert.equals(55, row.total);
  }

  function testNoParameters()
  {
    var row = db.prepare("SELECT 1 AS one").bindAllByName([]).executeQuery().next();
    Assert.equals(1, row.one);
  }

  function testMissingNameThrowsRange()
  {
    var stmt = db.prepare("SELECT :a, :b");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindAllByName([":a" => 1]))?.code);
  }

  function testUnknownNameThrowsRange()
  {
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindAllByName([":a" => 1, ":b" => 2]))?.code);
  }

  function testPositionalParameterThrowsRange()
  {
    var stmt = db.prepare("SELECT :a, ?");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindAllByName([":a" => 1]))?.code);
  }

  function testNumberingGapThrowsRange()
  {
    // ?3 alone makes three parameters, and 1 and 2 have no name.
    var stmt = db.prepare("SELECT ?3");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindAllByName(["?3" => 1]))?.code);
  }

  function testErrorBindsNothing()
  {
    var stmt = db.prepare("SELECT :a AS a, :b AS b").bindAllByName([":a" => 1, ":b" => 2]);
    catchError(() -> stmt.bindAllByName([":a" => 10, ":b" => 20, ":c" => 30]));
    catchError(() -> stmt.bindAllByName([":a" => 10]));
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindAllByName([
      ":a" => 10,
      ":b" => {
        x: 20
      }
    ]))?.code);
    var row = stmt.executeQuery().next();
    Assert.equals(1, row.a);
    Assert.equals(2, row.b);
  }

  function testUnsupportedTypeThrowsMisuse()
  {
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindAllByName([
      ":a" => {
        x: 1
      }
    ]))?.code);
  }

  function testNullMapThrowsMisuse()
  {
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindAllByName(null))?.code);
  }

  function testClosedStatementThrowsMisuse()
  {
    var stmt = db.prepare("SELECT :a");
    stmt.close();
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindAllByName([":a" => 1]))?.code);
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
