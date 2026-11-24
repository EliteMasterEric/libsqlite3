package sqlite;

#if cpp
import cpp.ConstCharStar;
import cpp.Finalizable;
import cpp.Pointer;
import cpp.RawPointer;
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
class SQLiteDatabase extends Finalizable {
	/**
	 * The C extern to interact with the SQLite database.
	 */
	private var db:Pointer<RawSQLite>;

	/**
	 * A list of statements on this database connection that are still open.
	 */
	private var statements:Array<SQLiteStatement> = [];

	public function new(db:Pointer<RawSQLite>) {
		super();
		this.db = db;
	}

	/**
	 * Ensure garbage collection closes the connection.
	 */
	public override function finalize() {
		if (db != null) {
			sqlite3_close_v2(db.raw);
			db = null;
		}
		super.finalize();
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

		var result:SQLiteResultCode = sqlite3_close_v2(db.raw);
		if (result != SQLiteResultCode.OK) {
			// Throw an error if SQLite can't close the connection.
			throw SQLiteException.fromConnection(db.raw);
		}

		db = null;
	}

	public function prepare(sql:String):SQLiteStatement {
		checkOpen();

		var rawStatement:RawPointer<RawSQLiteStatement> = null;
		var rawTail:ConstCharStar = null;

		var result:SQLiteResultCode = sqlite3_prepare_v2(db.raw, sql, -1, RawPointer.addressOf(rawStatement), RawPointer.addressOf(rawTail));
		if (result != SQLiteResultCode.OK) {
			throw SQLiteException.fromConnection(db.raw);
		}

		// SQLite returns `null` if the resulting statement was empty (or only had comments)
		if (rawStatement == null) {
			throw new SQLiteException("No SQL statement to prepare", SQLiteResultCode.MISUSE);
		}

		// Ensure an error is thrown if some of the statement is left trailing.
		var restStatement:RawPointer<RawSQLiteStatement> = null;
		var restTail:ConstCharStar = rawTail;
		while (true) {
			var rest:ConstCharStar = restTail;
			result = sqlite3_prepare_v2(db.raw, rest, -1, RawPointer.addressOf(restStatement), RawPointer.addressOf(restTail));
			if (result != SQLiteResultCode.OK || restStatement != null) {
				var message:String = 'Only one statement can be prepared at a time, but found more: "${(rest : String)}"';
				// The rest can fail to compile on its own, for example when it uses a table the first statement creates.
				if (result != SQLiteResultCode.OK) message += ' (${(sqlite3_errmsg(db.raw) : String)})';
				sqlite3_finalize(restStatement);
				sqlite3_finalize(rawStatement);
				throw new SQLiteException(message, SQLiteResultCode.MISUSE);
			}
			// Stop once SQLite consumes nothing more.
			if (restTail == rest) break;
		}

		var stmt = new SQLiteStatement(this, Pointer.fromRaw(rawStatement));
		statements.push(stmt);
		return stmt;
	}

	// Called by `SQLiteStatement.close()` once the statement is finalized.
	private function onStatementClosed(stmt:SQLiteStatement):Void {
		statements.remove(stmt);
	}

	public function lastInsertRowId():Int64 {
		checkOpen();
		return sqlite3_last_insert_rowid(db.raw);
	}

	public function changes():Int64 {
		checkOpen();

		return sqlite3_changes64(db.raw);
	}

	private function checkOpen():Void {
		if (db == null) throw new SQLiteException("Database is closed", SQLiteResultCode.MISUSE);
	}
}
#end