package regression;

import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * A statement prepared before a schema change is recompiled by its first step, so its columns must be read
 * after that step. They used to be read before it, keeping the old column list.
 */
class TestSchemaChange extends Test {
	function testAddedColumnIsReturned() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
		db.prepare("INSERT INTO t (x) VALUES (1)").executeStatement();
		var query = db.prepare("SELECT * FROM t");
		db.prepare("ALTER TABLE t ADD COLUMN y INTEGER DEFAULT 7").executeStatement();

		var row = query.executeQuery().next();
		Assert.same(["x", "y"], sortedFields(row));
		Assert.equals(7, row.y);
		db.close();
	}

	function testDroppedColumnIsNotReturned() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (x INTEGER, y INTEGER)").executeStatement();
		db.prepare("INSERT INTO t (x, y) VALUES (1, 2)").executeStatement();
		var query = db.prepare("SELECT * FROM t");
		db.prepare("ALTER TABLE t DROP COLUMN y").executeStatement();

		var row = query.executeQuery().next();
		Assert.same(["x"], sortedFields(row));
		db.close();
	}

	static function sortedFields(row:Dynamic):Array<String> {
		var fields = Reflect.fields(row);
		fields.sort(Reflect.compare);
		return fields;
	}
}
