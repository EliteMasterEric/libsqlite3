package sqlite;

#if cpp
import cpp.Pointer;
import cpp.RawPointer;
import haxe.Exception;
import sqlite._internal.RawSQLite;
import sqlite._internal.RawSQLite.*;

/**
 * Call `SQLite.open(path)` to get an SQLite Database object to perform queries on.
 * 
 * @see https://github.com/davidgiven/stellation/blob/stellation7/src/runtime/cpp/Sqlite.hx
 */
@:unreflective
class SQLite {
	public static function open(path:String):SQLiteDatabase {
		var db:RawPointer<RawSQLite> = null;
		var result:SQLiteResultCode = sqlite3_open(path, RawPointer.addressOf(db));
		if (result != SQLiteResultCode.OK) {
			// SQLite allocates the handle even when opening fails, so it must still be closed.
			// Copy the message first, since closing frees it.
			var message:String = sqlite3_errmsg(db);
			sqlite3_close_v2(db);
			throw new Exception(message);
		}
		return new SQLiteDatabase(Pointer.fromRaw(db));
	}
}
#end