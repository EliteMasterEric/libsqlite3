package cases;

import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import utest.Assert;
import utest.Test;

/**
 * `exec` runs a script of several statements without parameters, and discards any rows.
 */
class TestExec extends Test
{
  function testRunsEveryStatement()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER); INSERT INTO t VALUES (1); INSERT INTO t VALUES (2); PRAGMA user_version = 3;");

    Assert.equals(2, countRows(db));
    Assert.equals(3, queryInt(db, "PRAGMA user_version"));
    db.close();
  }

  function testRowsDiscarded()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER); SELECT 1, 2; INSERT INTO t VALUES (1)");

    Assert.equals(1, countRows(db));
    db.close();
  }

  function testUnicodeLiteral()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE s (v TEXT); INSERT INTO s VALUES ('héllo 日本')");

    var row:Dynamic = db.prepare("SELECT v FROM s").executeQuery().next();
    Assert.equals("héllo 日本", row.v);
    db.close();
  }

  function testEmptyRejected()
  {
    var db = SQLite.open(":memory:");
    assertThrows(SQLiteResultCode.MISUSE, () -> db.exec(""));
    assertThrows(SQLiteResultCode.MISUSE, () -> db.exec(" \n\t"));
    db.close();
  }

  function testCommentOnlyAccepted()
  {
    var db = SQLite.open(":memory:");
    db.exec("-- only a comment");
    db.exec("/* only a comment */");
    db.exec(";");
    Assert.pass();
    db.close();
  }

  function testNulRejected()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER)");
    assertThrows(SQLiteResultCode.MISUSE, () -> db.exec("INSERT INTO t VALUES (1);\x00INSERT INTO t VALUES (2)"));

    // Nothing ran, not even the statement before the NUL.
    Assert.equals(0, countRows(db));
    db.close();
  }

  function testErrorStopsScript()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER)");
    var e = assertThrows(SQLiteResultCode.ERROR, () -> db.exec("INSERT INTO t VALUES (1); INSERT INTO missing VALUES (2); INSERT INTO t VALUES (3)"));
    if (e != null) Assert.stringContains("missing", e.message);

    // Without a transaction in the script, statements before the error stay applied, and later ones don't run.
    Assert.equals(1, countRows(db));
    db.close();
  }

  function testRollbackOnErrorByDefault()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER)");
    assertThrows(SQLiteResultCode.ERROR, () -> db.exec("BEGIN; INSERT INTO t VALUES (1); INSERT INTO missing VALUES (2); COMMIT"));

    Assert.equals(0, countRows(db));
    // No transaction is left open.
    db.exec("BEGIN; COMMIT");
    Assert.pass();
    db.close();
  }

  function testNoRollbackWhenDisabled()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER)");
    assertThrows(SQLiteResultCode.ERROR, () -> db.exec("BEGIN; INSERT INTO t VALUES (1); INSERT INTO missing VALUES (2); COMMIT", {
      rollbackOnError: false
    }));

    // The transaction the script started is still open.
    assertThrows(SQLiteResultCode.ERROR, () -> db.exec("BEGIN"));
    Assert.equals(1, countRows(db));
    db.exec("ROLLBACK");
    Assert.equals(0, countRows(db));
    db.close();
  }

  function testCallerTransactionKept()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER)");
    db.exec("BEGIN");
    assertThrows(SQLiteResultCode.ERROR, () -> db.exec("INSERT INTO t VALUES (1); INSERT INTO missing VALUES (2)"));

    // The script didn't start the transaction, so it isn't rolled back.
    Assert.equals(1, countRows(db));
    db.exec("COMMIT");
    Assert.equals(1, countRows(db));
    db.close();
  }

  function testUseAfterClose()
  {
    var db = SQLite.open(":memory:");
    db.close();
    assertThrows(SQLiteResultCode.MISUSE, () -> db.exec("SELECT 1"));
  }

  static function countRows(db:SQLiteDatabase):Int
  {
    return queryInt(db, "SELECT COUNT(*) AS n FROM t");
  }

  static function queryInt(db:SQLiteDatabase, sql:String):Int
  {
    var statement = db.prepare(sql);
    var row:Dynamic = statement.executeQuery().next();
    statement.close();
    return Reflect.field(row, Reflect.fields(row)[0]);
  }

  static function assertThrows(code:SQLiteResultCode, f:() -> Void, ?pos:PosInfos):Null<SQLiteException>
  {
    try
    {
      f();
      Assert.fail('Expected an SQLiteException with code $code', pos);
    }
    catch (e:SQLiteException)
    {
      Assert.equals(code, e.code, e.message, pos);
      return e;
    }
    return null;
  }
}
