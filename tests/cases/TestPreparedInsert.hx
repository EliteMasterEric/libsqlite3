package cases;

import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import cases.util.DBCreator;
import utest.Async;
import utest.Test;

class TestPreparedInsert extends Test {
	function setupClass() {
		DBCreator.create();
	}

	function teardownClass(async:Async) {
		DBCreator.delete();
		async.done();
	}

	function testBasicInsert(async:Async) {
		var db = SQLite.open("persons.db");

		var stmt = db.prepare("INSERT INTO Person (lastName, firstName, iconId) VALUES (?, ?, ?)");
		stmt.bindString(1, "new last name");
		stmt.bindString(2, "new first name");
		stmt.bindInt(3, 1);
		stmt.executeQuery();

		var lastInsertedId = haxe.Int64.toInt(db.lastInsertRowId());
		Assert.equals(5, lastInsertedId);

		var stmt = db.prepare("SELECT * FROM Person WHERE personId = " + lastInsertedId);
		var rs = RecordUtils.toArray(stmt.executeQuery());

		Assert.equals(1, rs.length);

		Assert.equals(rs[0].personId, 5);
		Assert.equals(rs[0].firstName, "new first name");
		Assert.equals(rs[0].lastName, "new last name");
		Assert.equals(rs[0].iconId, 1);

		db.close();
		async.done();
	}
}
