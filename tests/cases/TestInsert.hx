package cases;

import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import cases.util.DBCreator;
import utest.Test;

class TestInsert extends Test {
	function setupClass() {
		DBCreator.create();
	}

	function testBasicInsert() {
		var db = SQLite.open("persons.db");

		var stmt = db.prepare("INSERT INTO Person (lastName, firstName, iconId) VALUES ('new last name', 'new first name', 1)");
		stmt.executeQuery();

		var lastInsertedId = haxe.Int64.toInt(db.lastInsertRowId());
		Assert.equals(5, lastInsertedId);

		var stmt = db.prepare("SELECT * FROM Person WHERE personId = " + lastInsertedId);
		var rs = RecordUtils.toArray(stmt.executeQuery());

		Assert.equals(1, rs.length);

		Assert.equals(5, rs[0].personId);
		Assert.equals("new first name", rs[0].firstName);
		Assert.equals("new last name", rs[0].lastName);
		Assert.equals(1, rs[0].iconId);

		db.close();
	}
}
