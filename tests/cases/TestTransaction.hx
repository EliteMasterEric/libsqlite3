package cases;

import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import sqlite.SQLiteTransactionMode;
import sys.FileSystem;
import utest.Assert;
import utest.Test;

/**
 * `begin()`, `commit()`, `rollback()` and `transaction()`.
 */
class TestTransaction extends Test
{
  static inline final PATH = "transaction-test.db";

  function setup()
  {
    if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
  }

  function teardown()
  {
    if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
  }

  function testBeginCommit()
  {
    var db = openWithTable();
    db.begin();
    db.exec("INSERT INTO t VALUES (1)");
    db.commit();
    Assert.equals(1, countRows(db));
    db.close();
  }

  function testBeginRollback()
  {
    var db = openWithTable();
    db.begin();
    db.exec("INSERT INTO t VALUES (1)");
    db.rollback();
    Assert.equals(0, countRows(db));
    db.close();
  }

  function testMisplacedCommands()
  {
    var db = openWithTable();
    assertThrows(SQLiteResultCode.ERROR, () -> db.commit());
    assertThrows(SQLiteResultCode.ERROR, () -> db.rollback());
    db.begin();
    assertThrows(SQLiteResultCode.ERROR, () -> db.begin());
    db.rollback();
    db.close();
  }

  function testImmediateTakesWriteLock()
  {
    var db = SQLite.open(PATH);
    db.exec("CREATE TABLE t (x INTEGER)");
    var other = SQLite.open(PATH);

    db.begin({mode: SQLiteTransactionMode.IMMEDIATE});
    assertThrows(SQLiteResultCode.BUSY, () -> other.exec("INSERT INTO t VALUES (1)"));
    db.commit();

    // A deferred transaction takes no lock until it reads or writes.
    db.begin();
    other.exec("INSERT INTO t VALUES (1)");
    db.commit();

    other.close();
    db.close();
  }

  function testTransactionCommitsAndReturns()
  {
    var db = openWithTable();
    var result = db.transaction(() ->
    {
      db.exec("INSERT INTO t VALUES (1); INSERT INTO t VALUES (2)");
      return "done";
    });
    Assert.equals("done", result);
    Assert.equals(2, countRows(db));
    // No transaction is left open.
    db.begin();
    db.commit();
    db.close();
  }

  function testVoidCallback()
  {
    var db = openWithTable();
    db.transaction(() -> db.exec("INSERT INTO t VALUES (1)"));
    db.transaction(() ->
    {
      db.exec("INSERT INTO t VALUES (2)");
    });
    Assert.equals(2, countRows(db));
    db.close();
  }

  function testSQLiteErrorRollsBack()
  {
    var db = openWithTable();
    var e = assertThrows(SQLiteResultCode.ERROR, () -> db.transaction(() ->
    {
      db.exec("INSERT INTO t VALUES (1)");
      db.exec("INSERT INTO missing VALUES (2)");
    }));
    if (e != null) Assert.stringContains("missing", e.message);
    Assert.equals(0, countRows(db));
    db.begin();
    db.commit();
    db.close();
  }

  function testOtherExceptionRethrownUnchanged()
  {
    var db = openWithTable();
    try
    {
      db.transaction(() ->
      {
        db.exec("INSERT INTO t VALUES (1)");
        throw "custom";
      });
      Assert.fail("transaction() did not throw");
    }
    catch (e:String)
    {
      Assert.equals("custom", e);
    }
    Assert.equals(0, countRows(db));
    db.close();
  }

  function testNestedFailureUndoesOnlyInnerWork()
  {
    var db = openWithTable();
    db.transaction(() ->
    {
      db.exec("INSERT INTO t VALUES (1)");
      try
      {
        db.transaction(() ->
        {
          db.exec("INSERT INTO t VALUES (2)");
          db.exec("INSERT INTO missing VALUES (3)");
        });
      }
      catch (e:SQLiteException) {}
      db.transaction(() -> db.exec("INSERT INTO t VALUES (4)"));
    });
    Assert.equals(2, countRows(db));
    Assert.equals(0, queryInt(db, "SELECT COUNT(*) FROM t WHERE x = 2"));
    db.close();
  }

  function testNestedInsideBegin()
  {
    var db = openWithTable();
    db.begin();
    db.transaction(() -> db.exec("INSERT INTO t VALUES (1)"));
    // The savepoint was released, but the transaction from begin() is still open.
    db.rollback();
    Assert.equals(0, countRows(db));
    db.close();
  }

  function testCallbackEndingTransactionRejected()
  {
    var db = openWithTable();
    assertThrows(SQLiteResultCode.MISUSE, () -> db.transaction(() ->
    {
      db.exec("INSERT INTO t VALUES (1)");
      db.commit();
    }));
    // The callback already committed, so its work can't be undone.
    Assert.equals(1, countRows(db));
    db.close();
  }

  function testFailedCommitRollsBack()
  {
    var db = SQLite.open(":memory:");
    db.exec("PRAGMA foreign_keys = ON;"
      + "CREATE TABLE parent (id INTEGER PRIMARY KEY);"
      + "CREATE TABLE t (x INTEGER REFERENCES parent(id) DEFERRABLE INITIALLY DEFERRED)");
    // The deferred foreign key is checked only at COMMIT, which fails and leaves the transaction open.
    assertThrows(SQLiteResultCode.CONSTRAINT, () -> db.transaction(() -> db.exec("INSERT INTO t VALUES (1)")));
    Assert.equals(0, countRows(db));
    db.begin();
    db.commit();
    db.close();
  }

  function testSQLiteRollbackKeepsOriginalError()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER UNIQUE)");
    // OR ROLLBACK makes SQLite end the transaction itself, so there is nothing left to roll back.
    assertThrows(SQLiteResultCode.CONSTRAINT, () -> db.transaction(() ->
    {
      db.exec("INSERT INTO t VALUES (1)");
      db.exec("INSERT OR ROLLBACK INTO t VALUES (1)");
    }));
    Assert.equals(0, countRows(db));
    db.close();
  }

  function testUseAfterClose()
  {
    var db = SQLite.open(":memory:");
    db.close();
    assertThrows(SQLiteResultCode.MISUSE, () -> db.begin());
    assertThrows(SQLiteResultCode.MISUSE, () -> db.commit());
    assertThrows(SQLiteResultCode.MISUSE, () -> db.rollback());
    assertThrows(SQLiteResultCode.MISUSE, () -> db.transaction(() -> 1));
  }

  static function openWithTable():SQLiteDatabase
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER)");
    return db;
  }

  static function countRows(db:SQLiteDatabase):Int
  {
    return queryInt(db, "SELECT COUNT(*) FROM t");
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
