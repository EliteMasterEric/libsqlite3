package cases;

import haxe.Exception;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * SQL errors are thrown as `haxe.Exception` carrying SQLite's message.
 */
class TestErrors extends Test
{
  function testSyntaxError()
  {
    var db = SQLite.open(":memory:");
    assertThrowsContaining(() -> db.prepare("SELEC 1"), "syntax error");
    db.close();
  }

  function testMissingTable()
  {
    var db = SQLite.open(":memory:");
    assertThrowsContaining(() -> db.prepare("SELECT * FROM missing"), "no such table");
    db.close();
  }

  function testConstraintViolation()
  {
    var db = SQLite.open(":memory:");
    db.prepare("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)").executeStatement();
    db.prepare("INSERT INTO t (name) VALUES ('a')").executeStatement();

    assertThrowsContaining(() -> db.prepare("INSERT INTO t (name) VALUES ('a')").executeStatement(), "UNIQUE constraint failed");
    assertThrowsContaining(() -> db.prepare("INSERT INTO t (name) VALUES (NULL)").executeStatement(), "NOT NULL constraint failed");
    db.close();
  }

  function testCloseTwiceIsHarmless()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare("SELECT 1");
    stmt.close();
    stmt.close();
    db.close();
    db.close();
    Assert.pass();
  }

  static function assertThrowsContaining(action:() -> Void, expected:String, ?pos:haxe.PosInfos):Void
  {
    try
    {
      action();
      Assert.fail('Expected an exception containing "$expected"', pos);
    }
    catch (e:Exception)
    {
      Assert.stringContains(expected, e.message, null, pos);
    }
  }
}
