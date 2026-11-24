package regression;

import haxe.Int64;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * Values must round-trip without truncation: integers wider than 32 bits, and text containing NUL characters.
 */
class TestNoTruncation extends Test {
	// 5000000000, which needs 33 bits.
	static final BIG:Int64 = Int64.make(1, 705032704);

	function testBigIntegerRoundTrip() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (id INTEGER PRIMARY KEY, big INTEGER, small INTEGER)").executeStatement();
		db.prepare("INSERT INTO t (big, small) VALUES (?, ?)").bindInt64(1, BIG).bindInt(2, 7).executeStatement();

		var row:Dynamic = db.prepare("SELECT big, small, -5000000000 AS negative FROM t").executeQuery().next();
		Assert.equals("5000000000", Int64.toStr(row.big));
		Assert.equals("-5000000000", Int64.toStr(row.negative));
		// Values that fit in 32 bits stay plain Ints. (`Int64.isInt64` is also true for an Int on cpp, so it can't check this.)
		Assert.equals(7, row.small);

		db.close();
	}

	function testInt32Boundaries() {
		var db = SQLite.open(":memory:");
		var row:Dynamic = db.prepare("SELECT 2147483647 AS max, -2147483648 AS min, 2147483648 AS over").executeQuery().next();
		Assert.equals(2147483647, row.max);
		Assert.equals(-2147483647 - 1, row.min);
		Assert.equals("2147483648", Int64.toStr(row.over));
		db.close();
	}

	function testBigRowIdAndChanges() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)").executeStatement();
		db.prepare("INSERT INTO t (id, name) VALUES (?, 'a')").bindInt64(1, BIG).executeStatement();

		Assert.equals("5000000000", Int64.toStr(db.lastInsertRowId()));
		Assert.equals("1", Int64.toStr(db.changes()));

		db.close();
	}

	function testTextWithNulRoundTrip() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (s TEXT)").executeStatement();
		var text = "before\x00after ✓";
		db.prepare("INSERT INTO t (s) VALUES (?)").bindString(1, text).executeStatement();

		var row:Dynamic = db.prepare("SELECT s, length(CAST(s AS BLOB)) AS n FROM t").executeQuery().next();
		// isTrue rather than equals: printing a NUL in the failure message cuts off the rest of the report.
		Assert.isTrue(text == row.s);
		Assert.equals(text.length, (row.s : String).length);
		// "before" + NUL + "after " + 3-byte check mark
		Assert.equals(16, row.n);

		db.close();
	}

	function testEmptyStringIsNotNull() {
		var db = SQLite.open(":memory:");
		var row:Dynamic = db.prepare("SELECT ? AS s, typeof(?) AS t").bindString(1, "").bindString(2, "").executeQuery().next();
		Assert.equals("", row.s);
		Assert.equals("text", row.t);
		db.close();
	}
}
