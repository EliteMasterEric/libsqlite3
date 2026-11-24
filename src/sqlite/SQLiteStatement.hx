package sqlite;

#if cpp
import cpp.Char;
import cpp.ConstPointer;
import cpp.NativeString;
import cpp.RawConstPointer;
import cpp.Stdlib;
import cpp.NativeArray;
import haxe.io.Bytes;
import haxe.Exception;
import haxe.Int64;
import cpp.Pointer;
import cpp.Finalizable;
import sqlite._internal.RawSQLite.*;
import sqlite._internal.RawSQLiteStatement;
import haxe.ds.Vector;

/**
 * Represents a prepared SQL statement to be performed.
 * Bind values and execute the query rather than concatenating strings to avoid SQL injection attacks.
 * Returns an `Iterator<Dynamic>` when the statement is executed, use this to count and view the results.
 */
@:unreflective
@:allow(sqlite.SQLiteDatabase)
class SQLiteStatement extends Finalizable {
	/**
	 * The database connection associated with this statement.
	 */
	private var owner:SQLiteDatabase;
	
	/**
	 * The C extern to interact with the SQLite statement.
	 */
	private var statement:Pointer<RawSQLiteStatement>;

	/**
	 * If `sqlite3_step` already threw an error, prevent `reset()` from throwing again.
	 */
	private var stepErrorThrown:Bool = false;

	private function new(owner:SQLiteDatabase, statement:Pointer<RawSQLiteStatement>) {
		super();
		this.owner = owner;
		this.statement = statement;
	}

	public override function finalize() {
		if (statement != null) {
			sqlite3_finalize(statement.raw);
			statement = null;
		}
		super.finalize();
	}

	/**
	 * Finalize the statement and frees its resources.
	 * It cannot be reused after this.
	 */
	public function close():Void {
		if (statement == null) return;

		sqlite3_finalize(statement.raw);
		owner.onStatementClosed(this);
		this.owner = null;
		this.statement = null;
	}

	public function reset():SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var result:SQLiteResultCode = sqlite3_reset(statement.raw);
		
		var alreadyThrown = stepErrorThrown;
		stepErrorThrown = false;
		if (result != SQLiteResultCode.OK && !alreadyThrown) {
			throw new Exception(sqlite3_errmsg(owner.db.raw));
		}

		return this;
	}

	public function bindInt(index:Int, value:Int):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var result:SQLiteResultCode = sqlite3_bind_int(statement.raw, index, value);
		if (result != SQLiteResultCode.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));

		return this;
	}

	public function bindInt64(index:Int, value:Int64):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var result:SQLiteResultCode = sqlite3_bind_int64(statement.raw, index, value);
		if (result != SQLiteResultCode.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));

		return this;
	}

	public function bindFloat(index:Int, value:Float):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var result:SQLiteResultCode = sqlite3_bind_double(statement.raw, index, value);
		if (result != SQLiteResultCode.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));

		return this;
	}

	public function bindString(index:Int, value:String):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		// Bind the full UTF-8 encoding with its length, so text containing NUL characters is not cut short.
		// (The implicit `ConstCharStar` conversion stops at the first NUL for non-ASCII strings.)
		var utf8 = Bytes.ofString(value);
		if (utf8.length == 0) {
			// Bind a literal rather than taking the address of an empty buffer (see `bindBytes`).
			var result:SQLiteResultCode = sqlite3_bind_text(statement.raw, index, "", 0, SQLITE_TRANSIENT);
			if (result != SQLiteResultCode.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));
		} else {
			var p:Pointer<Char> = NativeArray.address(utf8.getData(), 0).reinterpret();
			var result:SQLiteResultCode = sqlite3_bind_text(statement.raw, index, cast p.raw, utf8.length, SQLITE_TRANSIENT);
			if (result != SQLiteResultCode.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));
		}
		return this;
	}

	public function bindBytes(index:Int, value:Bytes):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var result:SQLiteResultCode;
		if (value.length == 0) {
			// Bind a zero blob instead of using NativeArray to prevent the array from auto-growing.
			result = sqlite3_bind_zeroblob(statement.raw, index, 0);
		} else {
			var p:Pointer<cpp.Void> = NativeArray.address(value.getData(), 0).reinterpret();
			result = sqlite3_bind_blob(statement.raw, index, p.raw, value.length, SQLITE_TRANSIENT);
		}
		if (result != SQLiteResultCode.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));
		return this;
	}

	public function executeStatement() {
		if (statement == null) throw new Exception("Statement is closed");

		var result:SQLiteResultCode = sqlite3_step(statement.raw);
		if (result != SQLiteResultCode.DONE) throwStepError(sqlite3_errmsg(owner.db.raw));
	}


	/**
	 * Throw an error resulting from a call to `sqlite3_step()`,
	 * then remember we did that so `sqlite3_reset()` doesn't rethrow the same error.
	 */
	private function throwStepError(message:String):Void {
		stepErrorThrown = true;
		throw new Exception(message);
	}

	public function executeQuery():Iterator<Dynamic> {
		if (statement == null) throw new Exception("Statement is closed");

		var columnCount = sqlite3_column_count(statement.raw);
		var columnNames = new Vector<String>(columnCount);
		for (i in 0...columnCount) {
			columnNames[i] = sqlite3_column_name(statement.raw, i);
		}

		var status:SQLiteResultCode = sqlite3_step(statement.raw);
		if (status != SQLiteResultCode.ROW && status != SQLiteResultCode.DONE) throwStepError(sqlite3_errmsg(owner.db.raw));

		// An error fetching the next row is kept and thrown by the next `hasNext()` or `next()` call,
		// so the row already fetched is still returned.
		var nextRowError:Null<String> = null;

		return {
			hasNext: () -> {
				if (nextRowError != null) throwStepError(nextRowError);
				return status == SQLiteResultCode.ROW;
			},
			next: () -> {
				if (statement == null) throw new Exception("Statement is closed");
				if (nextRowError != null) throwStepError(nextRowError);

				switch (status) {
					case DONE:
						return null;
					case ROW:
						var data = {};
						for (i in 0...columnCount) {
							var type:SQLiteColumnType = sqlite3_column_type(statement.raw, i);
							switch (type) {
								case INTEGER:
									// An `Int` when the value fits in 32 bits, otherwise an `Int64`.
									var value:Int64 = sqlite3_column_int64(statement.raw, i);
									if (value.high == value.low >> 31) {
										Reflect.setField(data, columnNames[i], value.low);
									} else {
										Reflect.setField(data, columnNames[i], value);
									}
								case FLOAT:
									Reflect.setField(data, columnNames[i], sqlite3_column_double(statement.raw, i));
								case TEXT:
									// Read the byte count after the text, as SQLite recommends, so embedded NULs are kept.
									var text:ConstPointer<Char> = ConstPointer.fromRaw(sqlite3_column_text(statement.raw, i)).reinterpret();
									var textBytes:Int = sqlite3_column_bytes(statement.raw, i);
									Reflect.setField(data, columnNames[i], NativeString.fromPointerLen(text, textBytes));
								case BLOB:
									// Copy into GC-owned Bytes: SQLite frees its buffer at the next step.
									// Read the byte count after the blob, as SQLite recommends.
									var blob:RawConstPointer<cpp.Void> = sqlite3_column_blob(statement.raw, i);
									var size:Int = sqlite3_column_bytes(statement.raw, i);
									var bytes = Bytes.alloc(size);
									if (size > 0) {
										var dest:Pointer<cpp.Void> = NativeArray.address(bytes.getData(), 0).reinterpret();
										Stdlib.nativeMemcpy(dest.raw, blob, size);
									}
									Reflect.setField(data, columnNames[i], bytes);
								case NULL:
									Reflect.setField(data, columnNames[i], null);
								case _:
									throw new Exception('Unknown column type ${type}');
							}
						}
						status = sqlite3_step(statement.raw);
						if (status != SQLiteResultCode.ROW && status != SQLiteResultCode.DONE) {
							nextRowError = sqlite3_errmsg(owner.db.raw);
						}
						return data;
					case _:
						// Unreachable: errors are thrown above, before the status is read.
						throw new Exception('Unexpected step result ${status}');
				}
			}
		}
	}
}
#end
