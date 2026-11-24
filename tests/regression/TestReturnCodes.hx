package regression;

import haxe.Exception;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * Failed `sqlite3_bind_*` and `sqlite3_reset` calls must throw, but a step error must not be thrown twice.
 */
class TestReturnCodes extends Test {
	function testBindOutOfRangeThrows() {
		var db = SQLite.open(":memory:");
		var stmt = db.prepare("SELECT ? AS v");

		Assert.raises(() -> stmt.bindInt(2, 1), Exception);
		Assert.raises(() -> stmt.bindInt(0, 1), Exception);
		Assert.raises(() -> stmt.bindString(2, "x"), Exception);
		// The valid index still works.
		stmt.bindInt(1, 7);
		Assert.equals(7, stmt.executeQuery().next().v);

		db.close();
	}

	function testResetAfterThrownStepErrorAllowsReuse() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (id INTEGER PRIMARY KEY)").executeStatement();
		var insert = db.prepare("INSERT INTO t (id) VALUES (?)");
		insert.bindInt(1, 1).executeStatement();

		// A duplicate key: executeStatement throws, and reset must not throw the same error again.
		insert.reset().bindInt(1, 1);
		Assert.raises(() -> insert.executeStatement(), Exception);
		insert.reset();

		insert.bindInt(1, 2).executeStatement();
		Assert.equals(2, db.prepare("SELECT count(*) AS n FROM t").executeQuery().next().n);

		db.close();
	}

	function testQueryStepErrorReportedOnce() {
		var db = SQLite.open(":memory:");
		// Integer overflow is a runtime error from sqlite3_step.
		var stmt = db.prepare("SELECT abs(-9223372036854775807 - 1) AS v");

		var thrown = 0;
		try {
			var rows = stmt.executeQuery();
			while (rows.hasNext()) rows.next();
		} catch (e:Exception) {
			thrown++;
		}
		try {
			stmt.reset();
		} catch (e:Exception) {
			thrown++;
		}
		Assert.equals(1, thrown);

		db.close();
	}
}
