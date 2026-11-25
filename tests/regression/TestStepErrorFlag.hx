package regression;

import haxe.Exception;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * A step error that was thrown must only stop `reset()` from throwing that same error. The flag used to stay
 * set until the next `reset()`, so a later step error that was never thrown was swallowed.
 */
class TestStepErrorFlag extends Test
{
  static inline final MIN_INT64 = "-9223372036854775807 - 1";

  function testLaterUnthrownErrorReportedByReset()
  {
    var db = SQLite.open(":memory:");
    db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
    db.prepare('INSERT INTO t (x) VALUES ($MIN_INT64)').executeStatement();
    // abs() of the smallest 64-bit integer overflows, which is a runtime error from sqlite3_step.
    var query = db.prepare("SELECT abs(x) AS v FROM t ORDER BY rowid");
    Assert.raises(() -> query.executeQuery(), Exception);

    // Without a reset, change the data so the error now comes from the second row.
    db.prepare("DELETE FROM t").executeStatement();
    db.prepare('INSERT INTO t (x) VALUES (1), ($MIN_INT64)').executeStatement();
    var rows = query.executeQuery();
    Assert.equals(1, rows.next().v);

    // Fetching the second row failed, but the iterator was abandoned before it threw.
    Assert.raises(() -> query.reset(), Exception);
    db.close();
  }
}
