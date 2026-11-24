package regression;

import cases.util.RecordUtils;
import haxe.Exception;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteStatement;
import utest.Assert;
import utest.Test;

/**
 * An iterator from an earlier execution must throw once its statement is reset, executed again, or closed.
 * It used to keep reading, returning a row of nulls and then restarting the query.
 */
class TestStaleIterator extends Test {
	function testThrowsAfterReset() {
		var db = SQLite.open(":memory:");
		var query = threeRows(db);
		var rows = query.executeQuery();
		rows.next();
		query.reset();
		Assert.raises(() -> rows.hasNext(), Exception);
		Assert.raises(() -> rows.next(), Exception);
		db.close();
	}

	function testThrowsAfterNewExecution() {
		var db = SQLite.open(":memory:");
		var query = threeRows(db);
		var rows = query.executeQuery();
		rows.next();
		var newRows = query.executeQuery();
		Assert.raises(() -> rows.hasNext(), Exception);
		Assert.raises(() -> rows.next(), Exception);
		// The new iterator is unaffected.
		Assert.same([1, 2, 3], RecordUtils.toArray(newRows).map(row -> row.v));
		db.close();
	}

	function testThrowsAfterExecuteStatement() {
		var db = SQLite.open(":memory:");
		var query = threeRows(db);
		var rows = query.executeQuery();
		rows.next();
		query.executeStatement();
		Assert.raises(() -> rows.hasNext(), Exception);
		Assert.raises(() -> rows.next(), Exception);
		db.close();
	}

	function testThrowsAfterClose() {
		var db = SQLite.open(":memory:");
		var query = threeRows(db);
		var rows = query.executeQuery();
		query.close();
		Assert.raises(() -> rows.hasNext(), Exception);
		Assert.raises(() -> rows.next(), Exception);
		db.close();
	}

	static function threeRows(db:SQLiteDatabase):SQLiteStatement {
		return db.prepare("SELECT value AS v FROM (SELECT 1 AS value UNION ALL SELECT 2 UNION ALL SELECT 3)");
	}
}
