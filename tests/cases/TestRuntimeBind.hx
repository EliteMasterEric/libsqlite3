package cases;

import haxe.Int64;
import haxe.PosInfos;
import haxe.io.Bytes;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import utest.Assert;
import utest.Test;

class TestRuntimeBind extends Test
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

  /**
   * Bind `value` with `bind()` and return SQLite's storage class for it, along with the value read back.
   */
  function bindOne(value:Any):Dynamic
  {
    return db.prepare("SELECT typeof(?1) AS type, ?1 AS value").bind(1, value).executeQuery().next();
  }

  function testInt()
  {
    var row = bindOne(42);
    Assert.equals("integer", row.type);
    Assert.equals(42, row.value);
  }

  function testInt64()
  {
    var row = bindOne(Int64.make(1, 0));
    Assert.equals("integer", row.type);
    Assert.equals("4294967296", Int64.toStr(row.value));
  }

  function testSmallInt64()
  {
    var row = bindOne(Int64.ofInt(-3));
    Assert.equals("integer", row.type);
    Assert.equals(-3, row.value);
  }

  function testFloat()
  {
    var row = bindOne(1.5);
    Assert.equals("real", row.type);
    Assert.equals(1.5, row.value);
  }

  function testInfinity()
  {
    var row = bindOne(Math.POSITIVE_INFINITY);
    Assert.equals("real", row.type);
    Assert.equals(Math.POSITIVE_INFINITY, row.value);
    row = db.prepare("SELECT typeof(?1) AS type, ?1 AS value").bindFloat(1, Math.NEGATIVE_INFINITY).executeQuery().next();
    Assert.equals("real", row.type);
    Assert.equals(Math.NEGATIVE_INFINITY, row.value);
  }

  function testNaNBindsNull()
  {
    // SQLite stores NaN as NULL.
    Assert.equals("null", bindOne(Math.NaN).type);
    var row = db.prepare("SELECT typeof(?) AS type").bindFloat(1, Math.NaN).executeQuery().next();
    Assert.equals("null", row.type);
  }

  function testWholeFloatInRealColumn()
  {
    // A whole Float is an Int at runtime on hxcpp, but REAL affinity stores it as a float.
    db.exec("CREATE TABLE t (x REAL)");
    var whole:Float = 2.0;
    db.prepare("INSERT INTO t (x) VALUES (?)").bind(1, whole).executeStatement();
    var row = db.prepare("SELECT typeof(x) AS type FROM t").executeQuery().next();
    Assert.equals("real", row.type);
  }

  function testWholeFloatInUntypedColumn()
  {
    // A whole Float is an Int at runtime on hxcpp, so a column with no type affinity stores an integer.
    // bindFloat always binds a floating point value.
    db.exec("CREATE TABLE t (x)");
    var whole:Float = 2.0;
    db.prepare("INSERT INTO t (x) VALUES (?)").bind(1, whole).executeStatement();
    db.prepare("INSERT INTO t (x) VALUES (?)").bindFloat(1, whole).executeStatement();
    var rows = cases.util.RecordUtils.toArray(db.prepare("SELECT typeof(x) AS type FROM t ORDER BY rowid").executeQuery());
    Assert.equals("integer", rows[0].type);
    Assert.equals("real", rows[1].type);
  }

  function testBindBool()
  {
    var row = db.prepare("SELECT typeof(?1) AS type, ?1 AS t, ?2 AS f").bindBool(1, true).bindBool(2, false).executeQuery().next();
    Assert.equals("integer", row.type);
    Assert.equals(1, row.t);
    Assert.equals(0, row.f);
  }

  function testBindBoolByName()
  {
    var row = db.prepare("SELECT :t AS t, :f AS f").bindBoolByName(":t", true).bindBoolByName(":f", false).executeQuery().next();
    Assert.equals(1, row.t);
    Assert.equals(0, row.f);
  }

  function testBindAllTypeErrorBindsNothing()
  {
    var stmt = db.prepare("SELECT ? AS a, ? AS b").bindAll([1, 2]);
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindAll([
      10,
      {
        x: 20
      }
    ]))?.code);
    var row = stmt.executeQuery().next();
    Assert.equals(1, row.a);
    Assert.equals(2, row.b);
  }

  function testBool()
  {
    var row = db.prepare("SELECT typeof(?1) AS type, ?1 AS t, ?2 AS f").bind(1, true).bind(2, false).executeQuery().next();
    Assert.equals("integer", row.type);
    Assert.equals(1, row.t);
    Assert.equals(0, row.f);
  }

  function testString()
  {
    var row = bindOne("text");
    Assert.equals("text", row.type);
    Assert.equals("text", row.value);
  }

  function testBytes()
  {
    var row = bindOne(Bytes.ofString("blob"));
    Assert.equals("blob", row.type);
    Assert.equals("blob", (row.value : Bytes).toString());
  }

  function testNull()
  {
    Assert.equals("null", bindOne(null).type);
  }

  function testUnsupportedTypeThrowsMisuse()
  {
    var stmt = db.prepare("SELECT ?");
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bind(1, {
      a: 1
    }))?.code);
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bind(1, [1, 2]))?.code);
  }

  function testBindByName()
  {
    var row = db.prepare("SELECT :a AS a, :b AS b").bindByName(":a", "x").bindByName(":b", 2.5).executeQuery().next();
    Assert.equals("x", row.a);
    Assert.equals(2.5, row.b);
  }

  function testBindByNameUnknownThrowsRange()
  {
    var stmt = db.prepare("SELECT :a");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindByName(":b", 1))?.code);
  }

  function testBindAll()
  {
    var row = db.prepare("SELECT ? AS i, ? AS s, ? AS f, ? IS NULL AS n").bindAll([1, "two", 3.5, null]).executeQuery().next();
    Assert.equals(1, row.i);
    Assert.equals("two", row.s);
    Assert.equals(3.5, row.f);
    Assert.equals(1, row.n);
  }

  function testBindAllNamedParameters()
  {
    // Named parameters are numbered by first appearance; a repeated name keeps its number.
    var row = db.prepare("SELECT :a AS a, :b AS b, :a AS c").bindAll([1, 2]).executeQuery().next();
    Assert.equals(1, row.a);
    Assert.equals(2, row.b);
    Assert.equals(1, row.c);
  }

  function testBindAllInsert()
  {
    db.exec("CREATE TABLE Person (name TEXT, age INTEGER)");
    var insert = db.prepare("INSERT INTO Person (name, age) VALUES (?, ?)");
    insert.bindAll(["Alice", 30]).executeStatement();
    insert.reset().bindAll(["Bob", 25]).executeStatement();
    var row = db.prepare("SELECT count(*) AS n, sum(age) AS total FROM Person").executeQuery().next();
    Assert.equals(2, row.n);
    Assert.equals(55, row.total);
  }

  function testBindAllNoParameters()
  {
    var row = db.prepare("SELECT 1 AS one").bindAll([]).executeQuery().next();
    Assert.equals(1, row.one);
  }

  function testBindAllWrongCountThrowsRange()
  {
    var stmt = db.prepare("SELECT ?, ?");
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindAll([1]))?.code);
    Assert.equals(SQLiteResultCode.RANGE, catchError(() -> stmt.bindAll([1, 2, 3]))?.code);
  }

  function testBindAllNullThrowsMisuse()
  {
    var stmt = db.prepare("SELECT ?");
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindAll(null))?.code);
  }

  function testClosedStatementThrowsMisuse()
  {
    var stmt = db.prepare("SELECT ?");
    stmt.close();
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bind(1, 1))?.code);
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> stmt.bindAll([1]))?.code);
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
