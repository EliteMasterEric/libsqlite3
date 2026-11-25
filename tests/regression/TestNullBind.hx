package regression;

import haxe.io.Bytes;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * Binding `null` must bind SQL NULL.
 * `bindString` used to bind an empty string, and `bindBytes` used to crash.
 */
class TestNullBind extends Test
{
  function testBindStringNull()
  {
    var db = SQLite.open(":memory:");
    var row = db.prepare("SELECT ? IS NULL AS boundNull").bindString(1, null).executeQuery().next();
    Assert.equals(1, row.boundNull);
    db.close();
  }

  function testBindBytesNull()
  {
    var db = SQLite.open(":memory:");
    var row = db.prepare("SELECT ? IS NULL AS boundNull").bindBytes(1, null).executeQuery().next();
    Assert.equals(1, row.boundNull);
    db.close();
  }

  // Replacing a bound value with null on reuse must also clear it.

  function testRebindNullAfterValue()
  {
    var db = SQLite.open(":memory:");
    var query = db.prepare("SELECT ? IS NULL AS boundNull");
    Assert.equals(0, query.bindString(1, "a").executeQuery().next().boundNull);
    Assert.equals(1, query.reset().bindString(1, null).executeQuery().next().boundNull);
    Assert.equals(0, query.reset().bindBytes(1, Bytes.ofString("a")).executeQuery().next().boundNull);
    Assert.equals(1, query.reset().bindBytes(1, null).executeQuery().next().boundNull);
    db.close();
  }
}
