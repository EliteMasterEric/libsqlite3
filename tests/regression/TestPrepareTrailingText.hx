package regression;

import haxe.Exception;
import haxe.Json;
import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import utest.Assert;
import utest.Test;

/**
 * `prepare` must accept whitespace and comments after the statement, but still reject a second statement,
 * and must reject SQL that contains no statement at all.
 */
class TestPrepareTrailingText extends Test {
	function testHarmlessTrailingTextAccepted() {
		var db = SQLite.open(":memory:");
		assertPrepares(db, "SELECT 1");
		assertPrepares(db, "SELECT 1;");
		assertPrepares(db, "SELECT 1; ");
		assertPrepares(db, "SELECT 1;\n");
		assertPrepares(db, "SELECT 1;\r\n\t");
		assertPrepares(db, "SELECT 1; -- trailing comment");
		assertPrepares(db, "SELECT 1; /* trailing comment */");
		assertPrepares(db, "SELECT 1;;");
		db.close();
	}

	function testSecondStatementRejected() {
		var db = SQLite.open(":memory:");
		assertRejects(db, "SELECT 1; SELECT 2");
		assertRejects(db, "SELECT 1; -- comment\nSELECT 2");
		db.close();
	}

	function testNoStatementRejected() {
		var db = SQLite.open(":memory:");
		assertRejects(db, "");
		assertRejects(db, "   ");
		assertRejects(db, "-- only a comment");
		assertRejects(db, ";");
		db.close();
	}

	// One assertion per SQL string, so a run reports every case that fails rather than stopping at the first.
	static function assertPrepares(db:SQLiteDatabase, sql:String, ?pos:PosInfos):Void {
		try {
			db.prepare(sql).close();
			Assert.pass(null, pos);
		} catch (e:Exception) {
			Assert.fail('prepare(${Json.stringify(sql)}) threw: ${e.message}', pos);
		}
	}

	static function assertRejects(db:SQLiteDatabase, sql:String, ?pos:PosInfos):Void {
		try {
			db.prepare(sql).close();
			Assert.fail('prepare(${Json.stringify(sql)}) did not throw', pos);
		} catch (e:Exception) {
			Assert.pass(null, pos);
		}
	}
}
