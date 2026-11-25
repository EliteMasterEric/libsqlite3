package regression;

import haxe.Exception;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * Using a database or statement after it is closed must throw an exception, not dereference a null handle.
 */
class TestUseAfterClose extends Test
{
  function testPrepareAfterDatabaseClose()
  {
    var db = SQLite.open(":memory:");
    db.close();

    Assert.raises(() -> db.prepare("SELECT 1"), Exception);
  }

  function testStatementAfterStatementClose()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT ?");
    stmt.close();

    Assert.raises(() -> stmt.bindInt(1, 1), Exception);
    Assert.raises(() -> stmt.reset(), Exception);
    Assert.raises(() -> stmt.executeStatement(), Exception);
    Assert.raises(() -> stmt.executeQuery(), Exception);

    db.close();
  }

  function testDatabaseInfoAfterClose()
  {
    var db = SQLite.open(":memory:");
    db.close();

    Assert.raises(() -> db.lastInsertRowId(), Exception);
    Assert.raises(() -> db.changes(), Exception);
  }

  // Every bind method checks for a closed statement, including the null paths that bind NULL.

  function testEveryBindAfterClose()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT ?");
    stmt.close();

    Assert.raises(() -> stmt.bindInt64(1, 1), Exception);
    Assert.raises(() -> stmt.bindFloat(1, 1.0), Exception);
    Assert.raises(() -> stmt.bindString(1, "x"), Exception);
    Assert.raises(() -> stmt.bindString(1, null), Exception);
    Assert.raises(() -> stmt.bindBytes(1, haxe.io.Bytes.alloc(1)), Exception);
    Assert.raises(() -> stmt.bindBytes(1, null), Exception);

    db.close();
  }

  function testStatementAfterDatabaseClose()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT ?");
    db.close();

    Assert.raises(() -> stmt.bindInt(1, 1), Exception);
    Assert.raises(() -> stmt.reset(), Exception);
    Assert.raises(() -> stmt.executeStatement(), Exception);
    Assert.raises(() -> stmt.executeQuery(), Exception);
  }
}
