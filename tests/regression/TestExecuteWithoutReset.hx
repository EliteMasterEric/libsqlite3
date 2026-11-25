package regression;

import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * Executing a statement again without `reset()` must start from the beginning. It used to continue the
 * previous execution, skipping the row the iterator had already fetched ahead.
 */
class TestExecuteWithoutReset extends Test
{
  function testExecuteQueryRestartsAfterPartialIteration()
  {
    var db = SQLite.open(":memory:");
    var query = db.prepare("SELECT value AS v FROM (SELECT 1 AS value UNION ALL SELECT 2 UNION ALL SELECT 3)");
    Assert.equals(1, query.executeQuery().next().v);

    var values = RecordUtils.toArray(query.executeQuery()).map(row -> row.v);
    Assert.same([1, 2, 3], values);
    db.close();
  }

  function testExecuteStatementRestartsAfterPartialIteration()
  {
    var db = SQLite.open(":memory:");
    db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
    var insert = db.prepare("INSERT INTO t (x) VALUES (1), (2) RETURNING x");
    insert.executeQuery().next();

    // Runs the insert a second time rather than finishing the first one.
    insert.executeStatement();
    Assert.equals(4, db.prepare("SELECT count(*) AS n FROM t").executeQuery().next().n);
    db.close();
  }
}
