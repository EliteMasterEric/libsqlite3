package cases;

import haxe.io.Bytes;
import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;
import cases.util.DBCreator;

class TestPreparedBlob extends Test {
	function setupClass() {
		DBCreator.create();
	}

	function testBasicBlobPreparedInsert() {
		var db = SQLite.open("persons.db");

		var stmt = db.prepare("INSERT INTO Person (lastName, firstName, iconId, contractDocument) VALUES (?, ?, ?, ?)");
		stmt.bindString(1, "new last name");
		stmt.bindString(2, "new first name");
		stmt.bindInt(3, 1);
		stmt.bindBytes(4, Bytes.ofString("this is a new contract document"));
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
		Assert.isOfType(rs[0].contractDocument, Bytes);
		Assert.equals(Bytes.ofString("this is a new contract document").toString(), rs[0].contractDocument.toString());

		db.close();
	}
}
