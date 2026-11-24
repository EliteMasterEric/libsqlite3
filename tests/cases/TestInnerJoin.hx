package cases;

import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import cases.util.DBCreator;
import utest.Test;

class TestInnerJoin extends Test {
	function setupClass() {
		DBCreator.create();
	}

	function testBasicInnerJoin() {
		var db = SQLite.open("persons.db");
		var stmt = db.prepare("SELECT * FROM Person
            INNER JOIN Icon ON Person.iconId = Icon.iconId
        ");
		var rs = RecordUtils.toArray(stmt.executeQuery());

		Assert.equals(4, rs.length);

		Assert.equals(1, rs[0].personId);
		Assert.equals("Ian", rs[0].firstName);
		Assert.equals("Harrigan", rs[0].lastName);
		Assert.equals(1, rs[0].iconId);
		Assert.equals("/somepath/icon1.png", rs[0].path);

		Assert.equals(3, rs[2].personId);
		Assert.equals("Tim", rs[2].firstName);
		Assert.equals("Mallot", rs[2].lastName);
		Assert.equals(2, rs[2].iconId);
		Assert.equals("/somepath/icon2.png", rs[2].path);

		db.close();
	}

	function testBasicInnerJoinWhere() {
		var db = SQLite.open("persons.db");
		var stmt = db.prepare("SELECT * FROM Person
            INNER JOIN Icon ON Person.iconId = Icon.iconId
        WHERE personId = 1");
		var rs = RecordUtils.toArray(stmt.executeQuery());

		Assert.equals(1, rs.length);

		Assert.equals(1, rs[0].personId);
		Assert.equals("Ian", rs[0].firstName);
		Assert.equals("Harrigan", rs[0].lastName);
		Assert.equals(1, rs[0].iconId);
		Assert.equals("/somepath/icon1.png", rs[0].path);

		db.close();
	}

	function testBasicInnerJoinWhereOr() {
		var db = SQLite.open("persons.db");
		var stmt = db.prepare("SELECT * FROM Person
            INNER JOIN Icon ON Person.iconId = Icon.iconId
        WHERE personId = 1 OR personId = 4");
		var rs = RecordUtils.toArray(stmt.executeQuery());

		Assert.equals(2, rs.length);

		Assert.equals(1, rs[0].personId);
		Assert.equals("Ian", rs[0].firstName);
		Assert.equals("Harrigan", rs[0].lastName);
		Assert.equals(1, rs[0].iconId);
		Assert.equals("/somepath/icon1.png", rs[0].path);

		Assert.equals(4, rs[1].personId);
		Assert.equals("Jim", rs[1].firstName);
		Assert.equals("Parker", rs[1].lastName);
		Assert.equals(1, rs[1].iconId);
		Assert.equals("/somepath/icon1.png", rs[1].path);

		db.close();
	}

	function testBasicInnerJoinWhereAnd() {
		var db = SQLite.open("persons.db");
		var stmt = db.prepare("SELECT * FROM Person
            INNER JOIN Icon ON Person.iconId = Icon.iconId
        WHERE personId = 1 AND firstName = 'Ian'");
		var rs = RecordUtils.toArray(stmt.executeQuery());

		Assert.equals(1, rs.length);

		Assert.equals(1, rs[0].personId);
		Assert.equals("Ian", rs[0].firstName);
		Assert.equals("Harrigan", rs[0].lastName);
		Assert.equals(1, rs[0].iconId);
		Assert.equals("/somepath/icon1.png", rs[0].path);

		db.close();
	}
}
