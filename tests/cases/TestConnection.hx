package cases;

import haxe.Int64;
import sqlite.SQLite;
import sys.FileSystem;
import utest.Assert;
import utest.Test;

/**
 * Opening, closing and reopening a database file.
 */
class TestConnection extends Test {
	static inline final PATH = "connection-test.db";

	function setup() {
		if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
	}

	function teardown() {
		if (FileSystem.exists(PATH)) FileSystem.deleteFile(PATH);
	}

	function testOpenCreatesFile() {
		var db = SQLite.open(PATH);
		db.close();
		Assert.isTrue(FileSystem.exists(PATH));
	}

	function testDataPersistsAcrossConnections() {
		var db = SQLite.open(PATH);
		db.prepare("CREATE TABLE t (name TEXT)").executeStatement();
		db.prepare("INSERT INTO t (name) VALUES (?)").bindString(1, "kept").executeStatement();
		db.close();

		var reopened = SQLite.open(PATH);
		var row:Dynamic = reopened.prepare("SELECT name FROM t").executeQuery().next();
		Assert.equals("kept", row.name);
		reopened.close();
	}

	function testLastInsertRowIdIncreases() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (id INTEGER PRIMARY KEY, x INTEGER)").executeStatement();
		db.prepare("INSERT INTO t (x) VALUES (1)").executeStatement();
		Assert.equals("1", Int64.toStr(db.lastInsertRowId()));
		db.prepare("INSERT INTO t (x) VALUES (2)").executeStatement();
		Assert.equals("2", Int64.toStr(db.lastInsertRowId()));
		db.close();
	}

	function testCloseFinalizesOpenStatements() {
		var db = SQLite.open(":memory:");
		var stmt = db.prepare("SELECT 1");
		db.close();
		Assert.raises(() -> stmt.executeQuery(), haxe.Exception);
	}
}
