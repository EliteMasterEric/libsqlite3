package cases;

import haxe.Int64;
import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import sys.FileSystem;
import utest.Assert;
import utest.Test;

using StringTools;

/**
 * `inTransaction()`, `totalChanges()`, `filename()`, `isReadOnly()`, and `SQLite.version`.
 */
class TestIntrospection extends Test
{
  static inline final PATH = "introspection-test.db";

  function setup()
  {
    if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
  }

  function teardown()
  {
    if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
  }

  function testInTransactionAfterBeginAndCommit()
  {
    var db = SQLite.open(":memory:");
    Assert.isFalse(db.inTransaction());
    db.begin();
    Assert.isTrue(db.inTransaction());
    db.commit();
    Assert.isFalse(db.inTransaction());
    db.close();
  }

  function testInTransactionAfterRollback()
  {
    var db = SQLite.open(":memory:");
    db.begin();
    Assert.isTrue(db.inTransaction());
    db.rollback();
    Assert.isFalse(db.inTransaction());
    db.close();
  }

  function testInTransactionInsideTransaction()
  {
    var db = SQLite.open(":memory:");
    var inside = db.transaction(() -> db.inTransaction());
    Assert.isTrue(inside);
    Assert.isFalse(db.inTransaction());
    db.close();
  }

  function testTotalChangesAddsUp()
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE t (x INTEGER)");
    Assert.equals("0", Int64.toStr(db.totalChanges()));
    db.exec("INSERT INTO t (x) VALUES (1), (2), (3)");
    db.exec("INSERT INTO t (x) VALUES (4)");
    db.exec("UPDATE t SET x = x + 1 WHERE x < 3");
    Assert.equals("2", Int64.toStr(db.changes()));
    Assert.equals("6", Int64.toStr(db.totalChanges()));
    db.close();
  }

  function testFilenameOfFile()
  {
    var db = SQLite.open(PATH);
    var name = db.filename();
    // SQLite returns an absolute path, so only compare the end.
    Assert.isTrue(name.endsWith(PATH), 'Expected "$name" to end with "$PATH"');
    Assert.isTrue(name.length > PATH.length);
    db.close();
  }

  function testFilenameOfMemory()
  {
    var db = SQLite.open(":memory:");
    Assert.equals("", db.filename());
    db.close();
  }

  function testFilenameOfBytes()
  {
    var db = SQLite.openFromBytes(makeBytes());
    Assert.equals("", db.filename());
    db.close();
  }

  function testIsReadOnlyWritable()
  {
    var db = SQLite.open(PATH);
    Assert.isFalse(db.isReadOnly());
    db.close();

    var bytes = SQLite.openFromBytes(makeBytes());
    Assert.isFalse(bytes.isReadOnly());
    bytes.close();
  }

  function testIsReadOnlyFile()
  {
    SQLite.open(PATH).close();
    var db = SQLite.open(PATH, {
      readOnly: true
    });
    Assert.isTrue(db.isReadOnly());
    db.close();
  }

  function testIsReadOnlyBytes()
  {
    var db = SQLite.openFromBytes(makeBytes(), {
      readOnly: true
    });
    Assert.isTrue(db.isReadOnly());
    db.close();
  }

  function testVersionMatchesVersionNumber()
  {
    var parts = SQLite.version.split(".");
    Assert.equals(3, parts.length);
    var number = Std.parseInt(parts[0]) * 1000000 + Std.parseInt(parts[1]) * 1000 + Std.parseInt(parts[2]);
    Assert.equals(SQLite.versionNumber, number);
  }

  function testUseAfterCloseThrows()
  {
    var db = SQLite.open(":memory:");
    db.close();
    assertMisuse(() -> db.inTransaction());
    assertMisuse(() -> db.totalChanges());
    assertMisuse(() -> db.filename());
    assertMisuse(() -> db.isReadOnly());
  }

  static function makeBytes():haxe.io.Bytes
  {
    var source = SQLite.open(":memory:");
    source.exec("CREATE TABLE t (x INTEGER); INSERT INTO t (x) VALUES (1);");
    var bytes = source.toBytes();
    source.close();
    return bytes;
  }

  static function assertMisuse(action:() -> Void, ?pos:PosInfos):Void
  {
    try
    {
      action();
    }
    catch (e:SQLiteException)
    {
      Assert.equals(SQLiteResultCode.MISUSE, e.code, pos);
      return;
    }
    Assert.fail("Expected an SQLiteException", pos);
  }
}
