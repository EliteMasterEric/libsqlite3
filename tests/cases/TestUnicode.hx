package cases;

import sqlite.SQLite;
import sys.FileSystem;
import utest.Assert;
import utest.Test;

/**
 * Non-ASCII text survives the trip through SQL, bound values, column names and file paths.
 * hxcpp stores such strings as UTF-16, so each path converts them to UTF-8.
 */
class TestUnicode extends Test
{
  static inline final TEXT = "héllo ✓ 日本語 😀";
  static inline final PATH = "unicodé-ü.db";

  function testBoundTextRoundTrip()
  {
    var db = SQLite.open(":memory:");
    var row = db.prepare("SELECT ? AS v, length(?) AS chars").bindString(1, TEXT).bindString(2, TEXT).executeQuery().next();
    Assert.equals(TEXT, row.v);
    // SQLite counts characters, so this checks the UTF-8 it received, not just the round trip.
    Assert.equals(13, row.chars);
    db.close();
  }

  function testTextInSql()
  {
    var db = SQLite.open(":memory:");
    var row = db.prepare('SELECT \'$TEXT\' AS v').executeQuery().next();
    Assert.equals(TEXT, row.v);
    db.close();
  }

  function testColumnName()
  {
    var db = SQLite.open(":memory:");
    var row = db.prepare('SELECT 1 AS "naïve ✓"').executeQuery().next();
    Assert.equals(1, Reflect.field(row, "naïve ✓"));
    db.close();
  }

  function testFilePath()
  {
    if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
    var db = SQLite.open(PATH);
    db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
    db.close();
    Assert.isTrue(FileSystem.exists(PATH));
    FileSystem.deleteFile(PATH);
  }
}
