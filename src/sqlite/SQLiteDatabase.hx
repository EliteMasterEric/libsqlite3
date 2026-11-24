package sqlite;

#if cpp
import cpp.Callable;
import cpp.Char;
import cpp.ConstCharStar;
import cpp.NativeArray;
import cpp.Pointer;
import cpp.RawPointer;
import cpp.vm.Gc;
import cpp.vm.WeakRef;
import haxe.Int64;
import haxe.io.Bytes;
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

		// Pass SQLite the raw bytes of the string to ensure strings containing NULL are handled correctly.
		var utf8 = Bytes.ofString(sql);
		var length = utf8.length;
		if (length == 0) throw new SQLiteException("No SQL statement to prepare", SQLiteResultCode.MISUSE);
		var start:Pointer<Char> = NativeArray.address(utf8.getData(), 0).reinterpret();

		var rawStatement:RawPointer<RawSQLiteStatement> = null;
		var tail:ConstCharStar = null;
		var result:SQLiteResultCode = sqlite3_prepare_v2(db.raw, cast start.raw, length, RawPointer.addressOf(rawStatement), RawPointer.addressOf(tail));
		if (result != SQLiteResultCode.OK) {
			throw SQLiteException.fromConnection(db.raw);
		}

		// SQLite returns `null` if the resulting statement was empty (or only had comments)
		if (rawStatement == null) {
			throw new SQLiteException("No SQL statement to prepare", SQLiteResultCode.MISUSE);
		}

		// Reject anything after the statement other than whitespace, comments and semicolons.
		var offset = tailOffset(start, tail, 0);
		while (offset < length) {
			var restStatement:RawPointer<RawSQLiteStatement> = null;
			result = sqlite3_prepare_v2(db.raw, cast start.add(offset).raw, length - offset, RawPointer.addressOf(restStatement), RawPointer.addressOf(tail));
			if (result != SQLiteResultCode.OK || restStatement != null) {
				// The rest can fail to compile on its own, for example when it uses a table the first statement creates.
				var error:Null<String> = result != SQLiteResultCode.OK ? sqlite3_errmsg(db.raw) : null;
				sqlite3_finalize(restStatement);
				sqlite3_finalize(rawStatement);
				var message = 'Only one statement can be prepared at a time, but found more: "${utf8.getString(offset, length - offset)}"';
				if (error != null) message += ' ($error)';
				throw new SQLiteException(message, SQLiteResultCode.MISUSE);
			}

			var nextOffset = tailOffset(start, tail, offset);
			// SQLite stops reading at a NUL character, so it consumes nothing when the rest starts with one.
			if (nextOffset == offset) {
				sqlite3_finalize(rawStatement);
				throw new SQLiteException("SQL must not contain a NUL character", SQLiteResultCode.MISUSE);
			}
			offset = nextOffset;
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

	/**
	 * @return How many bytes `tail` is past `start`.
	 * We know the value is at least `fromOffset`.
	 */
	private static function tailOffset(start:Pointer<Char>, tail:ConstCharStar, fromOffset:Int):Int {
		var offset = fromOffset;
		while ((cast start.add(offset).raw : ConstCharStar) != tail) {
			offset++;
		}
		return offset;
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