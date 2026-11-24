package sqlite;

#if cpp
import cpp.Callable;
import cpp.ConstCharStar;
import cpp.Pointer;
import cpp.RawPointer;
import cpp.vm.Gc;
import cpp.vm.WeakRef;
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
	 * Maintain weak references to the statements on this connection that are still open.
	 * `close()` needs to ensure all statements are finalized.
	 * Entries that have already been closed and cleaned up are ignored.
	 */
	private var statements:Array<WeakRef<SQLiteStatement>> = [];

	/**
	 * Calling `prepare()` cleans up the list only once `statements` reaches this length.
	 */
	private var pruneLength:Int = MIN_PRUNE_LENGTH;

	private static inline final MIN_PRUNE_LENGTH:Int = 16;

	/**
	 * Use `SQLite.open(path)` to connect to a database.
	 */
	@:allow(sqlite.SQLite)
	private function new(db:Pointer<RawSQLite>) {
		this.db = db;
		// Set a function to call when garbage collecting this object.
		Gc.setFinalizer(this, Callable.fromStaticFunction(onCollected));
	}

	/**
	 * Guarantee the extern statement gets finalized and cleaned up
	 * when garbage collecting this object.
	 */
	@:void
	private static function onCollected(database:SQLiteDatabase):Void {
		if (database.db != null) {
			sqlite3_close_v2(database.db.raw);
			database.db = null;
		}
	}

	/**
	 * Finalizes every open statement of this database, then closes the connection.
	 */
	public function close():Void {
		if (db == null) return;

		// Close each remaining unclosed statement.
		// onStatementClosed modifies this in place while we work, so we need to iterate a copy.
		for (ref in statements.copy()) {
			var statement = ref.get();
			if (statement != null) statement.close();
		}
		statements = [];

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

		// Prune
		if (statements.length >= pruneLength) {
			statements = statements.filter(ref -> ref.get() != null);
			pruneLength = Std.int(Math.max(MIN_PRUNE_LENGTH, statements.length * 2));
		}

		statements.push(new WeakRef(stmt));
		return stmt;
	}

	// Called by `SQLiteStatement.close()` once the statement is finalized.
	private function onStatementClosed(stmt:SQLiteStatement):Void {
		// Remove the closed statement from `statements`
		for (i in 0...statements.length) {
			if (statements[i].get() == stmt) {
				statements.splice(i, 1);
				return;
			}
		}
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