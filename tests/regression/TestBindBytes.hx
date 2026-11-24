package regression;

import haxe.io.Bytes;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * `bindBytes` must bind its value as a BLOB, byte for byte.
 */
class TestBindBytes extends Test {
	function testAllByteValuesRoundTrip() {
		var data = Bytes.alloc(256);
		for (i in 0...256) {
			data.set(i, i);
		}

		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (data BLOB)").executeStatement();
		db.prepare("INSERT INTO t (data) VALUES (?)").bindBytes(1, data).executeStatement();

		var row:Dynamic = db.prepare("SELECT data, typeof(data) AS type, length(data) AS n FROM t").executeQuery().next();
		Assert.equals("blob", row.type);
		Assert.equals(256, row.n);
		Assert.isOfType(row.data, Bytes);
		Assert.equals(data.toHex(), (row.data : Bytes).toHex());

		db.close();
	}

	function testEmptyBytesBindsEmptyBlob() {
		var db = SQLite.open(":memory:");
		var empty = Bytes.alloc(0);
		var row:Dynamic = db.prepare("SELECT ? AS data, typeof(?) AS type").bindBytes(1, empty).bindBytes(2, empty).executeQuery().next();

		// An empty value must stay an empty BLOB, not become NULL.
		Assert.equals("blob", row.type);
		Assert.isOfType(row.data, Bytes);
		Assert.equals(0, (row.data : Bytes).length);
		// Binding must not change the caller's buffer.
		Assert.equals(0, empty.getData().length);

		db.close();
	}

	function testBoundValueIsUsedInQuery() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (id INTEGER, data BLOB)").executeStatement();
		db.prepare("INSERT INTO t (id, data) VALUES (1, x'0102'), (2, x'0304')").executeStatement();

		var row:Dynamic = db.prepare("SELECT id FROM t WHERE data = ?").bindBytes(1, Bytes.ofHex("0304")).executeQuery().next();
		Assert.equals(2, row.id);

		db.close();
	}
}
