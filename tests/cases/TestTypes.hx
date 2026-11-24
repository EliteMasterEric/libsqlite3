package cases;

import haxe.io.Bytes;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * Each SQLite storage class reads back as the documented Haxe type.
 */
class TestTypes extends Test {
	function testNull() {
		var db = SQLite.open(":memory:");
		var row:Dynamic = db.prepare("SELECT NULL AS v").executeQuery().next();
		Assert.isTrue(Reflect.hasField(row, "v"));
		Assert.isNull(row.v);
		db.close();
	}

	function testFloat() {
		var db = SQLite.open(":memory:");
		var row:Dynamic = db.prepare("SELECT 3.25 AS literal, ? AS bound, 2.0 AS whole, typeof(?) AS type")
			.bindFloat(1, -1.5)
			.bindFloat(2, -1.5)
			.executeQuery()
			.next();
		Assert.equals(3.25, row.literal);
		Assert.equals(-1.5, row.bound);
		// A REAL with no fractional part is still a Float.
		Assert.isOfType(row.whole, Float);
		Assert.equals(2.0, row.whole);
		Assert.equals("real", row.type);
		db.close();
	}

	function testEmptyTextAndBlob() {
		var db = SQLite.open(":memory:");
		var row:Dynamic = db.prepare("SELECT '' AS text, x'' AS blob").executeQuery().next();
		Assert.equals("", row.text);
		Assert.isOfType(row.blob, Bytes);
		Assert.equals(0, (row.blob : Bytes).length);
		db.close();
	}

	function testAllTypesInOneRow() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (i INTEGER, r REAL, s TEXT, b BLOB, n TEXT)").executeStatement();
		db.prepare("INSERT INTO t VALUES (?, ?, ?, ?, NULL)")
			.bindInt(1, 42)
			.bindFloat(2, 0.5)
			.bindString(3, "text")
			.bindBytes(4, Bytes.ofHex("00ff"))
			.executeStatement();

		var row:Dynamic = db.prepare("SELECT * FROM t").executeQuery().next();
		Assert.equals(42, row.i);
		Assert.equals(0.5, row.r);
		Assert.equals("text", row.s);
		Assert.equals("00ff", (row.b : Bytes).toHex());
		Assert.isNull(row.n);
		db.close();
	}

	function testColumnAliasesNameFields() {
		var db = SQLite.open(":memory:");
		var row:Dynamic = db.prepare("SELECT 1 AS first, 2 AS \"second name\"").executeQuery().next();
		Assert.equals(1, row.first);
		Assert.equals(2, Reflect.field(row, "second name"));
		db.close();
	}
}
