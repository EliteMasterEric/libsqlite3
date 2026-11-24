package sqlite;

#if cpp
import cpp.ConstCharStar;
import cpp.Pointer;
import cpp.RawPointer;
import haxe.Exception;
import haxe.Int64;
import sqlite._internal.RawSQLite;
import sqlite._internal.RawSQLite.*;
import sqlite._internal.RawSQLiteStatement;

/**
 * Represents an SQLite database that is currently loaded.
 * 
 * Call `SQLiteDatabase.prepare(sql)` to create a prepared statement, bind values to it, then execute the query.
 */
@:unreflective
@:allow(sqlite.SQLiteStatement)
class SQLiteDatabase {
	/**
	 * The C extern to interact with the SQLite database.
	 */
	private var db:Pointer<RawSQLite>;

	/**
	 * A list of statements on this database connection that are still open.
	 */
	private var statements:Array<SQLiteStatement> = [];

	public function new(db:Pointer<RawSQLite>) {
		this.db = db;
	}

	/**
	 * Finalizes every open statement of this database, then closes the connection.
	 */
	public function close():Void {
		if (db == null) return;

		// Iterate a copy of the statements array, so we don't modify the array we're iterating.
		for (statement in statements.copy()) {
			statement.close();
		}

		var result = sqlite3_close(db.raw);
		if (result != SQLite.OK) {
			// Throw an error if SQLite can't close the connection.
			throw new Exception(sqlite3_errmsg(db.raw));
		}

		db = null;
	}

	public function prepare(sql:String):SQLiteStatement {
		if (db == null) throw "Database is closed";

		var rawStatement:RawPointer<RawSQLiteStatement> = null;
		var rawTail:ConstCharStar = null;

		var i = sqlite3_prepare_v2(db.raw, sql, -1, RawPointer.addressOf(rawStatement), RawPointer.addressOf(rawTail));
		if (i != 0) {
			throw new Exception(sqlite3_errmsg(db.raw));
		}

		var stmt = new SQLiteStatement(this, Pointer.fromRaw(rawStatement));
		statements.push(stmt);

		var tail:String = rawTail;
		if (tail != "") {
			stmt.close();
			throw new Exception('Some of statement ignored: "${tail}"');
		}

		return stmt;
	}

	// Called by `SQLiteStatement.close()` once the statement is finalized.
	private function onStatementClosed(stmt:SQLiteStatement):Void {
		statements.remove(stmt);
	}

	public function lastInsertRowId():Int64 {
		if (db == null) throw "Database is closed";
		return sqlite3_last_insert_rowid(db.raw);
	}

	public function changes():Int64 {
		if (db == null) throw "Database is closed";
		
		return sqlite3_changes64(db.raw);
	}
}
#end