package cases;

import haxe.io.Bytes;
import cases.util.RecordUtils;
import sqlite.Sqlite;
import utest.Assert;
import utest.Test;
import cases.util.DBCreator;
import utest.Async;

class TestBlob extends Test {
	function setupClass() {
		DBCreator.create();
	}

	function teardownClass(async:Async) {
		DBCreator.delete();
		async.done();
	}

	function testBasicBlob(async:Async) {
		var db = Sqlite.open("persons.db");
		var stmt = db.prepare("SELECT * FROM Person WHERE personId = 1");
		var rs = RecordUtils.toArray(stmt.executeQuery());

		Assert.equals(1, rs.length);

		Assert.equals(rs[0].personId, 1);
		Assert.equals(rs[0].firstName, "Ian");
		Assert.equals(rs[0].lastName, "Harrigan");
		Assert.equals(rs[0].iconId, 1);
		Assert.isOfType(rs[0].contractDocument, Bytes);
		Assert.equals(Bytes.ofString("this is ians contract document").toString(), rs[0].contractDocument.toString());

		async.done();
	}

	function testBasicBlobInsert(async:Async) {
		var db = Sqlite.open("persons.db");

		var stmt = db.prepare("INSERT INTO Person (lastName, firstName, iconId, contractDocument) VALUES ('new last name', 'new first name', 1, X'746869732069732061206e657720636f6e747261637420646f63756d656e74')");
		stmt.executeQuery();

		var lastInsertedId = db.lastInsertRowId();
		Assert.equals(5, lastInsertedId);

		var stmt = db.prepare("SELECT * FROM Person WHERE personId = " + lastInsertedId);
		var rs = RecordUtils.toArray(stmt.executeQuery());

		Assert.equals(1, rs.length);

		Assert.equals(rs[0].personId, 5);
		Assert.equals(rs[0].firstName, "new first name");
		Assert.equals(rs[0].lastName, "new last name");
		Assert.equals(rs[0].iconId, 1);
		Assert.isOfType(rs[0].contractDocument, Bytes);
		Assert.equals(Bytes.ofString("this is a new contract document").toString(), rs[0].contractDocument.toString());

		db.close();
		async.done();
	}
}
