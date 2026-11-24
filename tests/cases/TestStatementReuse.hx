package cases;

import cases.util.RecordUtils;
import haxe.Int64;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * A prepared statement can be reset, rebound, and executed again.
 */
class TestStatementReuse extends Test {
	function testInsertManyRowsWithOneStatement() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (name TEXT)").executeStatement();

		var insert = db.prepare("INSERT INTO t (name) VALUES (?)");
		for (name in ["a", "b", "c"]) {
			insert.reset().bindString(1, name).executeStatement();
		}

		var rows = RecordUtils.toArray(db.prepare("SELECT name FROM t ORDER BY name").executeQuery());
		Assert.equals(3, rows.length);
		Assert.equals("a", rows[0].name);
		Assert.equals("c", rows[2].name);
		db.close();
	}

	function testQueryAgainAfterReset() {
		var db = SQLite.open(":memory:");
		var query = db.prepare("SELECT value AS v FROM (SELECT 1 AS value UNION ALL SELECT 2)");

		Assert.equals(2, RecordUtils.toArray(query.executeQuery()).length);
		Assert.equals(2, RecordUtils.toArray(query.reset().executeQuery()).length);
		db.close();
	}

	function testResetAfterPartialIteration() {
		var db = SQLite.open(":memory:");
		var query = db.prepare("SELECT value AS v FROM (SELECT 1 AS value UNION ALL SELECT 2 UNION ALL SELECT 3)");

		var rows = query.executeQuery();
		Assert.equals(1, rows.next().v);

		// Starting again returns every row, from the first.
		var all = RecordUtils.toArray(query.reset().executeQuery());
		Assert.equals(3, all.length);
		Assert.equals(1, all[0].v);
		db.close();
	}

	function testRebindChangesResult() {
		var db = SQLite.open(":memory:");
		var query = db.prepare("SELECT ? * 2 AS v");
		Assert.equals(4, query.bindInt(1, 2).executeQuery().next().v);
		Assert.equals(10, query.reset().bindInt(1, 5).executeQuery().next().v);
		db.close();
	}

	function testEmptyResult() {
		var db = SQLite.open(":memory:");
		var rows = db.prepare("SELECT 1 AS v WHERE 0").executeQuery();
		Assert.isFalse(rows.hasNext());
		Assert.isNull(rows.next());
		db.close();
	}

	function testChangesCountsAffectedRows() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
		db.prepare("INSERT INTO t (x) VALUES (1), (2), (3)").executeStatement();
		Assert.equals("3", Int64.toStr(db.changes()));

		db.prepare("UPDATE t SET x = x + 10 WHERE x >= 2").executeStatement();
		Assert.equals("2", Int64.toStr(db.changes()));
		db.close();
	}
}
