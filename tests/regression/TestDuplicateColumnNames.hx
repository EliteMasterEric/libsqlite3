package regression;

import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import utest.Assert;
import utest.Test;

/**
 * `executeQuery()` keys rows by column name, so two result columns with the same name
 * (such as `iconId` in `SELECT * FROM Person JOIN Icon ...`) used to overwrite each other silently.
 * It now throws `MISUSE` instead.
 */
class TestDuplicateColumnNames extends Test
{
  function testDuplicateAliasesThrow()
  {
    var db = SQLite.open(":memory:");
    assertMisuse(() -> db.prepare("SELECT 1 AS a, 2 AS a").executeQuery());
    db.close();
  }

  function testJoinWithSharedColumnThrows()
  {
    var db = joinedTables();
    assertMisuse(() -> db.prepare("SELECT * FROM p JOIN i ON p.iconId = i.iconId").executeQuery());
    db.close();
  }

  // The column names don't depend on the rows, so an empty result throws too.

  function testEmptyResultThrows()
  {
    var db = joinedTables();
    assertMisuse(() -> db.prepare("SELECT * FROM p JOIN i ON p.iconId = i.iconId WHERE 0").executeQuery());
    db.close();
  }

  // Haxe field names are case-sensitive, so these don't collide.

  function testNamesDifferingInCaseAreAllowed()
  {
    var db = SQLite.open(":memory:");
    var row:Dynamic = db.prepare("SELECT 1 AS a, 2 AS A").executeQuery().next();
    Assert.equals(1, row.a);
    Assert.equals(2, row.A);
    db.close();
  }

  function testAliasedJoinWorks()
  {
    var db = joinedTables();
    var row:Dynamic = db.prepare("SELECT p.iconId AS personIcon, i.iconId AS iconIcon FROM p JOIN i ON p.iconId = i.iconId")
      .executeQuery()
      .next();
    Assert.equals(7, row.personIcon);
    Assert.equals(7, row.iconIcon);
    db.close();
  }

  // executeStatement() discards rows, so duplicate names don't matter to it.

  function testExecuteStatementAllowsDuplicates()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT 1 AS a, 2 AS a");
    stmt.executeStatement();
    Assert.pass();
    db.close();
  }

  // The statement isn't left mid-execution, and stays usable.

  function testStatementUsableAfterError()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT 1 AS a, 2 AS a");
    assertMisuse(() -> stmt.executeQuery());
    assertMisuse(() -> stmt.executeQuery());
    stmt.executeStatement();
    Assert.isFalse(db.inTransaction());
    db.close();
  }

  static function joinedTables():SQLiteDatabase
  {
    var db = SQLite.open(":memory:");
    db.exec("CREATE TABLE p (name TEXT, iconId INTEGER);
      CREATE TABLE i (iconId INTEGER, path TEXT);
      INSERT INTO p VALUES ('x', 7);
      INSERT INTO i VALUES (7, 'icon.png');");
    return db;
  }

  static function assertMisuse(action:() -> Void, ?pos:haxe.PosInfos):Void
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
    Assert.fail("Expected a MISUSE SQLiteException", pos);
  }
}
