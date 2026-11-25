package regression;

import haxe.Exception;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * A `sqlite3_step` error during `executeQuery` must throw, not end the iteration early as if there were no
 * more rows.
 */
class TestQueryErrors extends Test
{
  // abs() of the smallest 64-bit integer overflows, which is a runtime error from sqlite3_step.
  static inline final OVERFLOW = "abs(-9223372036854775807 - 1)";

  function testErrorOnFirstRowThrows()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare('SELECT $OVERFLOW AS v');
    Assert.raises(() -> stmt.executeQuery(), Exception);
    db.close();
  }

  function testErrorOnLaterRowThrows()
  {
    var db = SQLite.open(":memory:");
    var stmt = db.prepare('SELECT abs(x) AS v FROM (SELECT 1 AS x UNION ALL SELECT -9223372036854775807 - 1)');
    var rows = stmt.executeQuery();

    // The first row is fine; the error comes from fetching the second.
    Assert.isTrue(rows.hasNext());
    Assert.equals(1, rows.next().v);
    Assert.raises(() -> rows.hasNext(), Exception);

    db.close();
  }
}
