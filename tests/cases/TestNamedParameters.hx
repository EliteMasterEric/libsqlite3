package cases;

import cases.util.RecordUtils;
import haxe.Int64;
import haxe.PosInfos;
import haxe.io.Bytes;
import sqlite.SQLite;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import utest.Assert;
import utest.Test;

class TestNamedParameters extends Test
{
  function testBindEachType()
  {
    var db = SQLite.open(":memory:");
    var row = db
      .prepare("SELECT :i AS i, :big AS big, :f AS f, :s AS s, :b AS b, :n IS NULL AS n")
      .bindIntByName(":i", 42)
      .bindInt64ByName(":big", Int64.make(1, 0))
      .bindFloatByName(":f", 1.5)
      .bindStringByName(":s", "text")
      .bindBytesByName(":b", Bytes.ofString("blob"))
      .bindNullByName(":n")
      .executeQuery()
      .next();
    Assert.equals(42, row.i);
    Assert.equals("4294967296", Int64.toStr(row.big));
    Assert.equals(1.5, row.f);
    Assert.equals("text", row.s);
    Assert.equals("blob", (row.b : Bytes).toString());
    Assert.equals(1, row.n);
    db.close();
  }

  function testNullStringAndBytesBindNull()
  {
    var db = SQLite.open(":memory:");
    var row = db.prepare("SELECT :s IS NULL AS s, :b IS NULL AS b").bindStringByName(":s", null).bindBytesByName(":b", null).executeQuery().next();
    Assert.equals(1, row.s);
    Assert.equals(1, row.b);
    db.close();
  }

  function testEachPrefix()
  {
    var db = SQLite.open(":memory:");
    var row = db
      .prepare("SELECT :a AS a, @b AS b, $c AS c, ?4 AS d")
      .bindIntByName(":a", 1)
      .bindIntByName("@b", 2)
      .bindIntByName("$c", 3)
      .bindIntByName("?4", 4)
      .executeQuery()
      .next();
    Assert.equals(1, row.a);
    Assert.equals(2, row.b);
    Assert.equals(3, row.c);
    Assert.equals(4, row.d);
    db.close();
  }

  function testNonAsciiNames()
  {
    // Names go to SQLite as UTF-8 C strings and come back from sqlite3_bind_parameter_name.
    var db = SQLite.open(":memory:");
    var sql = "SELECT :café AS a, :名前 AS b, :😀 AS c";
    var row = db.prepare(sql).bindIntByName(":café", 1).bindStringByName(":名前", "x").bindByName(":😀", 2.5).executeQuery().next();
    Assert.equals(1, row.a);
    Assert.equals("x", row.b);
    Assert.equals(2.5, row.c);

    row = db.prepare(sql).bindAllByName([":café" => 3, ":名前" => "y", ":😀" => 4.5]).executeQuery().next();
    Assert.equals(3, row.a);
    Assert.equals("y", row.b);
    Assert.equals(4.5, row.c);

    var stmt = db.prepare("SELECT :café AS a");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindIntByName(":cafe", 1))?.code);
    db.close();
  }

  function testNonAsciiObjectFields()
  {
    var db = SQLite.open(":memory:");
    var fields:Dynamic = {};
    Reflect.setField(fields, "café", 1);
    Reflect.setField(fields, "名前", "x");
    var row = db.prepare("SELECT :café AS a, @名前 AS b").bindObject(fields).executeQuery().next();
    Assert.equals(1, row.a);
    Assert.equals("x", row.b);
    db.close();
  }

  function testRepeatedNameBindsEveryUse()
  {
    var db = SQLite.open(":memory:");
    var row = db.prepare("SELECT :x AS a, :x + 1 AS b").bindIntByName(":x", 10).executeQuery().next();
    Assert.equals(10, row.a);
    Assert.equals(11, row.b);
    db.close();
  }

  function testMixedWithPositional()
  {
    var db = SQLite.open(":memory:");
    // `?` after a named parameter takes the next index, so it is 2 here.
    var row = db.prepare("SELECT :a AS a, ? AS b").bindIntByName(":a", 1).bindInt(2, 2).executeQuery().next();
    Assert.equals(1, row.a);
    Assert.equals(2, row.b);
    db.close();
  }

  function testInsertAndReuse()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE Person (name TEXT, age INTEGER)");
    var insert = db.prepare("INSERT INTO Person (name, age) VALUES (:name, :age)");
    insert.bindStringByName(":name", "Alice").bindIntByName(":age", 30).executeStatement();
    insert.reset().bindStringByName(":name", "Bob").bindIntByName(":age", 25).executeStatement();

    var rows = RecordUtils.toArray(db.prepare("SELECT name, age FROM Person ORDER BY age").executeQuery());
    Assert.equals(2, rows.length);
    Assert.equals("Bob", rows[0].name);
    Assert.equals(25, rows[0].age);
    Assert.equals("Alice", rows[1].name);
    Assert.equals(30, rows[1].age);
    db.close();
  }

  function testUnknownNameThrowsRange()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindIntByName(":b", 1))?.code);
    db.close();
  }

  function testNameWithoutPrefixThrowsRange()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT :a");
    var error = catchError(() -> stmt.bindIntByName("a", 1));
    Assert.equals(SQLiteResultCode.RANGE, error?.code);
    Assert.isTrue(error?.message.indexOf('":a"') != -1);
    db.close();
  }

  function testNamesAreCaseSensitive()
  {
    // SQLite compares parameter names with memcmp.
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindIntByName(":A", 1))?.code);
    db.close();
  }

  function testNullNameThrowsMisuse()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindIntByName(null, 1))?.code);
    db.close();
  }

  function testNameWithNulThrowsMisuse()
  {
    // As a C string, ":a\0b" would end at the NUL and match ":a".
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindIntByName(":a\x00b", 1))?.code);
    db.close();
  }

  function testClosedStatementThrowsMisuse()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT :a");
    stmt.close();
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindIntByName(":a", 1))?.code);
    db.close();
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
