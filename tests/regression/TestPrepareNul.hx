package regression;

import haxe.Exception;
import haxe.PosInfos;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import utest.Assert;
import utest.Test;

/**
 * `prepare` passed the SQL to SQLite as a NUL-terminated string, so SQLite never saw the text after a NUL
 * character, and a second statement there was dropped without an error.
 */
class TestPrepareNul extends Test {
	function testTextAfterNulRejected() {
		var db = SQLite.open(":memory:");
		assertRejects(db, "SELECT 1\x00; SELECT 2");
		assertRejects(db, "SELECT 1;\x00SELECT 2");
		assertRejects(db, "SELECT 1\x00garbage");
		// Non-ASCII SQL goes through a different UTF-8 conversion, which also stopped at the NUL.
		assertRejects(db, "SELECT 'é'\x00; SELECT 2");
		db.close();
	}

	// Printing a NUL cuts off the console output (`Json.stringify` doesn't escape it on cpp), so it is shown as `\0`.
	static function assertRejects(db:SQLiteDatabase, sql:String, ?pos:PosInfos):Void {
		try {
			db.prepare(sql).close();
			var shown = StringTools.replace(sql, "\x00", "\\0");
			Assert.fail('prepare("$shown") did not throw', pos);
		} catch (e:Exception) {
			Assert.pass(null, pos);
		}
	}
}
