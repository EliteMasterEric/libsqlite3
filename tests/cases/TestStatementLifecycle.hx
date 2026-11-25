package cases;

import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * Several statements on one connection work independently, and closing one leaves the others usable.
 */
class TestStatementLifecycle extends Test
{
  function testExecuteQueryOnStatementWithoutRows()
  {
    var db = SQLite.open(":memory:");
    db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
    var rows = db.prepare("INSERT INTO t (x) VALUES (1)").executeQuery();
    Assert.isFalse(rows.hasNext());
    Assert.equals(1, db.prepare("SELECT count(*) AS n FROM t").executeQuery().next().n);
    db.close();
  }

  function testInterleavedQueries()
  {
    var db = SQLite.open(":memory:");
    var numbers = db.prepare("SELECT value AS v FROM (SELECT 1 AS value UNION ALL SELECT 2 UNION ALL SELECT 3)");
    var letters = db.prepare("SELECT value AS v FROM (SELECT 'a' AS value UNION ALL SELECT 'b' UNION ALL SELECT 'c')");
    var a = numbers.executeQuery();
    var b = letters.executeQuery();

    var seen:Array<String> = [];
    while (a.hasNext() && b.hasNext())
    {
      seen.push('${a.next().v}${b.next().v}');
    }
    Assert.same(["1a", "2b", "3c"], seen);
    db.close();
  }

  function testClosingOneStatementLeavesOthersUsable()
  {
    var db = SQLite.open(":memory:");
    var first = db.prepare("SELECT 1 AS v");
    var second = db.prepare("SELECT 2 AS v");
    first.close();
    Assert.equals(2, second.executeQuery().next().v);
    // The same statement can be executed many times; every execution starts over.
    for (_ in 0...3)
    {
      Assert.equals(1, RecordUtils.toArray(second.executeQuery()).length);
    }
    db.close();
  }

  function testWritesDuringQueryOfAnotherTable()
  {
    var db = SQLite.open(":memory:");
    db.prepare("CREATE TABLE source (x INTEGER)").executeStatement();
    db.prepare("CREATE TABLE copy (x INTEGER)").executeStatement();
    db.prepare("INSERT INTO source (x) VALUES (1), (2), (3)").executeStatement();

    var insert = db.prepare("INSERT INTO copy (x) VALUES (?)");
    for (row in db.prepare("SELECT x FROM source ORDER BY x").executeQuery())
    {
      insert.reset().bindInt(1, row.x * 10).executeStatement();
    }
    var copied = RecordUtils.toArray(db.prepare("SELECT x FROM copy ORDER BY x").executeQuery()).map(row -> row.x);
    Assert.same([10, 20, 30], copied);
    db.close();
  }
}
