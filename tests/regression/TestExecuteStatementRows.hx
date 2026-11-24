package regression;

import haxe.Exception;
import sqlite.SQLite;
import sys.FileSystem;
import utest.Assert;
import utest.Test;

/**
 * `executeStatement` must run a statement that returns rows to completion. It used to throw
 * "another row available" and leave the statement active, holding its lock.
 */
class TestExecuteStatementRows extends Test {
	static inline final PATH = "returning-lock.db";

	function testPragmaReturningRow() {
		var db = SQLite.open(":memory:");
		db.prepare("PRAGMA cache_size").executeStatement();
		Assert.pass();
		db.close();
	}

	function testSelectReturningRows() {
		var db = SQLite.open(":memory:");
		db.prepare("SELECT 1 UNION ALL SELECT 2").executeStatement();
		Assert.pass();
		db.close();
	}

	function testInsertReturningReleasesLock() {
		deleteDatabase();
		var db = SQLite.open(PATH);
		db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
		db.prepare("INSERT INTO t (x) VALUES (1), (2) RETURNING x").executeStatement();
		Assert.equals(2, db.prepare("SELECT count(*) AS n FROM t").executeQuery().next().n);

		// A second connection can only write once the first statement has finished.
		var other = SQLite.open(PATH);
		try {
			other.prepare("INSERT INTO t (x) VALUES (3)").executeStatement();
			Assert.pass();
		} catch (e:Exception) {
			Assert.fail('Second connection could not write: ${e.message}');
		}
		other.close();
		db.close();
		deleteDatabase();
	}

	static function deleteDatabase():Void {
		for (file in [PATH, PATH + "-journal"]) {
			if (FileSystem.exists(file)) FileSystem.deleteFile(file);
		}
	}
}
