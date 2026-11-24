package cases;

import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteException;
import sqlite.SQLiteExtendedResultCode;
import sqlite.SQLiteResultCode;
import sys.FileSystem;
import utest.Assert;
import utest.Test;

/**
 * Errors are thrown as `SQLiteException`, carrying SQLite's primary and extended result codes.
 */
class TestErrorCodes extends Test {
	static inline final BUSY_PATH = "busy-test.db";

	function testSyntaxError() {
		var db = SQLite.open(":memory:");
		var e = catchError(() -> db.prepare("SELEC 1"));
		assertCodes(e, SQLiteResultCode.ERROR, SQLiteExtendedResultCode.ERROR);
		Assert.stringContains("syntax error", e.message);
		db.close();
	}

	function testConstraintViolations() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT UNIQUE)").executeStatement();
		db.prepare("INSERT INTO t (id, name) VALUES (1, 'a')").executeStatement();

		var unique = catchError(() -> db.prepare("INSERT INTO t (id, name) VALUES (2, 'a')").executeStatement());
		assertCodes(unique, SQLiteResultCode.CONSTRAINT, SQLiteExtendedResultCode.CONSTRAINT_UNIQUE);
		var primaryKey = catchError(() -> db.prepare("INSERT INTO t (id, name) VALUES (1, 'b')").executeStatement());
		assertCodes(primaryKey, SQLiteResultCode.CONSTRAINT, SQLiteExtendedResultCode.CONSTRAINT_PRIMARYKEY);
		db.prepare("CREATE TABLE n (x INTEGER NOT NULL)").executeStatement();
		var notNull = catchError(() -> db.prepare("INSERT INTO n (x) VALUES (NULL)").executeStatement());
		assertCodes(notNull, SQLiteResultCode.CONSTRAINT, SQLiteExtendedResultCode.CONSTRAINT_NOTNULL);
		db.close();
	}

	function testBindOutOfRange() {
		var db = SQLite.open(":memory:");
		var stmt = db.prepare("SELECT ? AS v");
		assertCodes(catchError(() -> stmt.bindInt(2, 1)), SQLiteResultCode.RANGE, SQLiteExtendedResultCode.RANGE);
		db.close();
	}

	function testFailedOpen() {
		var e = catchError(() -> SQLite.open("missing-folder/sub/test.db"));
		Assert.equals(SQLiteResultCode.CANTOPEN, e.code);
	}

	function testBusy() {
		deleteBusyDatabase();
		var holder = SQLite.open(BUSY_PATH);
		holder.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
		holder.prepare("BEGIN EXCLUSIVE").executeStatement();

		var other = SQLite.open(BUSY_PATH);
		var e = catchError(() -> other.prepare("INSERT INTO t (x) VALUES (1)").executeStatement());
		Assert.equals(SQLiteResultCode.BUSY, e.code);
		other.close();
		holder.close();
		deleteBusyDatabase();
	}

	// A row error thrown later by the iterator keeps the code from when the row failed, even if the
	// connection reported a different error in between.
	function testDeferredRowErrorKeepsItsCode() {
		var db = SQLite.open(":memory:");
		db.prepare("CREATE TABLE u (x INTEGER UNIQUE)").executeStatement();
		db.prepare("INSERT INTO u (x) VALUES (1)").executeStatement();
		// abs() of the smallest 64-bit integer overflows, which is a runtime error from sqlite3_step.
		var rows = db.prepare("SELECT abs(x) AS v FROM (SELECT 1 AS x UNION ALL SELECT -9223372036854775807 - 1)").executeQuery();
		rows.next();

		catchError(() -> db.prepare("INSERT INTO u (x) VALUES (1)").executeStatement());
		var e = catchError(() -> rows.hasNext());
		assertCodes(e, SQLiteResultCode.ERROR, SQLiteExtendedResultCode.ERROR);
		Assert.stringContains("integer overflow", e.message);
		db.close();
	}

	function testMisuseDetectedByWrapper() {
		var db = SQLite.open(":memory:");
		assertCodes(catchError(() -> db.prepare("")), SQLiteResultCode.MISUSE, SQLiteExtendedResultCode.MISUSE);
		assertCodes(catchError(() -> db.prepare("SELECT 1; SELECT 2")), SQLiteResultCode.MISUSE, SQLiteExtendedResultCode.MISUSE);

		var query = db.prepare("SELECT 1 AS v UNION ALL SELECT 2");
		var rows = query.executeQuery();
		query.reset();
		assertCodes(catchError(() -> rows.next()), SQLiteResultCode.MISUSE, SQLiteExtendedResultCode.MISUSE);

		query.close();
		assertCodes(catchError(() -> query.executeQuery()), SQLiteResultCode.MISUSE, SQLiteExtendedResultCode.MISUSE);
		db.close();
		assertCodes(catchError(() -> db.prepare("SELECT 1")), SQLiteResultCode.MISUSE, SQLiteExtendedResultCode.MISUSE);
	}

	static function catchError(action:() -> Void, ?pos:PosInfos):Null<SQLiteException> {
		try {
			action();
		} catch (e:SQLiteException) {
			return e;
		}
		Assert.fail("Expected an SQLiteException", pos);
		return null;
	}

	static function assertCodes(e:Null<SQLiteException>, code:SQLiteResultCode, extendedCode:SQLiteExtendedResultCode, ?pos:PosInfos):Void {
		if (e == null) return;
		Assert.equals(code, e.code, pos);
		Assert.equals(extendedCode, e.extendedCode, pos);
	}

	static function deleteBusyDatabase():Void {
		for (file in [BUSY_PATH, BUSY_PATH + "-journal"]) {
			if (FileSystem.exists(file)) FileSystem.deleteFile(file);
		}
	}
}
