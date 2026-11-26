package cases;

import haxe.Int64;
import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import sys.FileSystem;
import utest.Assert;
import utest.Test;

/**
 * Opening, closing and reopening a database file.
 */
class TestConnection extends Test
{
  static inline final PATH = "connection-test.db";

  function setup()
  {
    if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
  }

  function teardown()
  {
    if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
  }

  function testOpenCreatesFile()
  {
    var db = SQLite.open(PATH);
    db.close();
    Assert.isTrue(FileSystem.exists(PATH));
  }

  function testDataPersistsAcrossConnections()
  {
    var db = SQLite.open(PATH);
    db.prepare("CREATE TABLE t (name TEXT)").executeStatement();
    db.prepare("INSERT INTO t (name) VALUES (?)").bindString(1, "kept").executeStatement();
    db.close();

    var reopened = SQLite.open(PATH);
    var row:Dynamic = reopened.prepare("SELECT name FROM t").executeQuery().next();
    Assert.equals("kept", row.name);
    reopened.close();
  }

  function testReadOnlyReadsButRejectsWrites()
  {
    var db = SQLite.open(PATH);
    db.prepare("CREATE TABLE t (name TEXT)").executeStatement();
    db.prepare("INSERT INTO t (name) VALUES ('kept')").executeStatement();
    db.close();

    var readOnly = SQLite.open(PATH, {
      readOnly: true
    });
    var row:Dynamic = readOnly.prepare("SELECT name FROM t").executeQuery().next();
    Assert.equals("kept", row.name);
    var e = catchError(() -> readOnly.prepare("INSERT INTO t (name) VALUES ('new')").executeStatement());
    if (e != null) Assert.equals(SQLiteResultCode.READONLY, e.code);
    readOnly.close();
  }

  // Read-only never creates the file.

  function testReadOnlyMissingFile()
  {
    var e = catchError(() -> SQLite.open(PATH, {
      readOnly: true
    }));
    if (e != null) Assert.equals(SQLiteResultCode.CANTOPEN, e.code);
    Assert.isFalse(FileSystem.exists(PATH));
  }

  function testReadOnlyFalseCreatesFile()
  {
    SQLite.open(PATH, {
      readOnly: false
    }).close();
    Assert.isTrue(FileSystem.exists(PATH));
  }

  function testCreateIfMissingFalseThrows()
  {
    var e = catchError(() -> SQLite.open(PATH, {
      createIfMissing: false
    }));
    if (e != null) Assert.equals(SQLiteResultCode.CANTOPEN, e.code);
    Assert.isFalse(FileSystem.exists(PATH));
  }

  function testCreateIfMissingFalseOpensExisting()
  {
    SQLite.open(PATH).close();
    var db = SQLite.open(PATH, {
      createIfMissing: false
    });
    db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
    db.prepare("INSERT INTO t (x) VALUES (1)").executeStatement();
    Assert.equals("1", Int64.toStr(db.changes()));
    db.close();
  }

  function testReadOnlyWithCreateIfMissingThrows()
  {
    var e = catchError(() -> SQLite.open(PATH, {
      readOnly: true,
      createIfMissing: true
    }));
    if (e != null) Assert.equals(SQLiteResultCode.MISUSE, e.code);
    Assert.isFalse(FileSystem.exists(PATH));
  }

  function testLastInsertRowIdIncreases()
  {
    var db = SQLite.open(":memory:");
    db.prepare("CREATE TABLE t (id INTEGER PRIMARY KEY, x INTEGER)").executeStatement();
    db.prepare("INSERT INTO t (x) VALUES (1)").executeStatement();
    Assert.equals("1", Int64.toStr(db.lastInsertRowId()));
    db.prepare("INSERT INTO t (x) VALUES (2)").executeStatement();
    Assert.equals("2", Int64.toStr(db.lastInsertRowId()));
    db.close();
  }

  function testCloseFinalizesOpenStatements()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT 1");
    db.close();
    Assert.raises(() -> stmt.executeQuery(), haxe.Exception);
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
