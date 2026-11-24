package sqlite;

#if cpp
import cpp.Char;
import cpp.ConstPointer;
import cpp.NativeString;
import cpp.RawConstPointer;
import cpp.Stdlib;
import cpp.NativeArray;
import haxe.io.Bytes;
import haxe.Int64;
import cpp.Pointer;
import cpp.Callable;
import cpp.vm.Gc;
import sqlite._internal.RawSQLite.*;
import sqlite._internal.RawSQLiteStatement;
import haxe.ds.Vector;

/**
 * Represents a prepared SQL statement to be performed.
 * 
 * NOTES:
 * - Bind values and execute the query rather than concatenating strings to avoid SQL injection attacks.
 * - 
 * - Call `reset()` and you can bind new values and reuse the query object!
 * @see https://www.sqlite.org/cintro.html
 */
@:unreflective
@:allow(sqlite.SQLiteDatabase)
class SQLiteStatement {
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

	/**
	 * Increments every time `reset()` gets thrown.
	 * If an old `Iterator<Dynamic>` returned by `executeQuery()` is reused 
	 */
	private var execution:Int = 0;

	private function new(owner:SQLiteDatabase, statement:Pointer<RawSQLiteStatement>) {
		this.owner = owner;
		this.statement = statement;
		// Set a function to call when garbage collecting this object.
		Gc.setFinalizer(this, Callable.fromStaticFunction(onCollected));
	}

	/**
	 * Guarantee the extern statement gets finalized and cleaned up
	 * when garbage collecting this object.
	 */
	@:void
	private static function onCollected(stmt:SQLiteStatement):Void {
		if (stmt.statement != null) {
			sqlite3_finalize(stmt.statement.raw);
			stmt.statement = null;
		}
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

	/**
	 * Resets the statement so it can be bound and executed again. Bound values are kept.
	 * Iterators returned by earlier `executeQuery()` calls throw after this.
	 * Throws a step error of the last execution that was not already thrown.
	 */
	public function reset():SQLiteStatement {
		checkOpen();

		execution++;
		var result:SQLiteResultCode = sqlite3_reset(statement.raw);
		
		var alreadyThrown = stepErrorThrown;
		stepErrorThrown = false;
		if (result != SQLiteResultCode.OK && !alreadyThrown) {
			throw SQLiteException.fromConnection(owner.db.raw);
		}

		return this;
	}

	/**
	 * Bind the `index`th parameter with the provided value, as an number.
	 * 
	 * @return Self, for chaining calls.
	 */
	public function bindInt(index:Int, value:Int):SQLiteStatement {
		checkOpen();

		var result:SQLiteResultCode = sqlite3_bind_int(statement.raw, index, value);
		if (result != SQLiteResultCode.OK) throw SQLiteException.fromConnection(owner.db.raw);

		return this;
	}

	/**
	 * Bind the `index`th parameter with the provided value, as a 64-bit number.
	 * 
	 * @return Self, for chaining calls.
	 */
	public function bindInt64(index:Int, value:Int64):SQLiteStatement {
		checkOpen();

		var result:SQLiteResultCode = sqlite3_bind_int64(statement.raw, index, value);
		if (result != SQLiteResultCode.OK) throw SQLiteException.fromConnection(owner.db.raw);

		return this;
	}

	/**
	 * Bind the `index`th parameter with the provided value, as a floating point value.
	 * 
	 * @return Self, for chaining calls.
	 */
	public function bindFloat(index:Int, value:Float):SQLiteStatement {
		checkOpen();

		var result:SQLiteResultCode = sqlite3_bind_double(statement.raw, index, value);
		if (result != SQLiteResultCode.OK) throw SQLiteException.fromConnection(owner.db.raw);

		return this;
	}

	/**
	 * Bind the `index`th parameter with the provided value, as a string (or `NULL` if the input is null).
	 * 
	 * @return Self, for chaining calls.
	 */
	public function bindString(index:Int, value:Null<String>):SQLiteStatement {
		checkOpen();
		if (value == null) return bindNull(index);

		// Convert the string to bytes to prevent issues with 0x0 / non-ASCII characters.
		var utf8 = Bytes.ofString(value);
		if (utf8.length == 0) {
			var result:SQLiteResultCode = sqlite3_bind_text(statement.raw, index, "", 0, SQLITE_TRANSIENT);
			if (result != SQLiteResultCode.OK) throw SQLiteException.fromConnection(owner.db.raw);
		} else {
			var p:Pointer<Char> = NativeArray.address(utf8.getData(), 0).reinterpret();
			var result:SQLiteResultCode = sqlite3_bind_text(statement.raw, index, cast p.raw, utf8.length, SQLITE_TRANSIENT);
			if (result != SQLiteResultCode.OK) throw SQLiteException.fromConnection(owner.db.raw);
		}
		return this;
	}

	/**
	 * Bind the `index`th parameter with the provided value, as a binary blob (or `NULL` if the input is null).
	 * 
	 * @return Self, for chaining calls.
	 */
	public function bindBytes(index:Int, value:Null<Bytes>):SQLiteStatement {
		checkOpen();
		if (value == null) return bindNull(index);

		var result:SQLiteResultCode;
		if (value.length == 0) {
			// Bind a zero blob instead of using NativeArray to prevent the array from auto-growing.
			result = sqlite3_bind_zeroblob(statement.raw, index, 0);
		} else {
			var p:Pointer<cpp.Void> = NativeArray.address(value.getData(), 0).reinterpret();
			result = sqlite3_bind_blob(statement.raw, index, p.raw, value.length, SQLITE_TRANSIENT);
		}
		if (result != SQLiteResultCode.OK) throw SQLiteException.fromConnection(owner.db.raw);
		return this;
	}

	/**
	 * Binds the `index`th parameter with `NULL`.
	 * 
	 * @return Self, for chaining calls.
	 */
	private function bindNull(index:Int):SQLiteStatement {
		var result:SQLiteResultCode = sqlite3_bind_null(statement.raw, index);
		if (result != SQLiteResultCode.OK) throw SQLiteException.fromConnection(owner.db.raw);
		return this;
	}

	/**
	 * Resets the statement and runs it to completion.
	 * Any rows it returns are discarded, use `executeQuery()` if you care about the results.
	 */
	public function executeStatement():Void {
		reset();

		var result:SQLiteResultCode = step();
		while (result == SQLiteResultCode.ROW) {
			result = step();
		}
		if (result != SQLiteResultCode.DONE) throwStepError(SQLiteException.fromConnection(owner.db.raw));
	}

	/**
	 * Advance the statement to the next result row.
	 */
	private function step():SQLiteResultCode {
		stepErrorThrown = false;
		return sqlite3_step(statement.raw);
	}

	/**
	 * Throw an error resulting from a call to `sqlite3_step()`,
	 * then remember we did that so `sqlite3_reset()` doesn't rethrow the same error.
	 */
	private function throwStepError(error:SQLiteException):Void {
		stepErrorThrown = true;
		throw error;
	}

	private function checkOpen():Void {
		if (statement == null) throw new SQLiteException("Statement is closed", SQLiteResultCode.MISUSE);
	}

	/**
	 * Resets the statement and runs it with the provided parameters.
	 * 
	 * @returns An `Iterator<Dynamic>` over each row in the query results.
	 * 	 The rows are anonymous structures, where each column is a field on the object.
	 */
	public function executeQuery():Iterator<Dynamic> {
		reset();
		var thisExecution:Int = execution;

		var status:SQLiteResultCode = step();
		if (status != SQLiteResultCode.ROW && status != SQLiteResultCode.DONE) throwStepError(SQLiteException.fromConnection(owner.db.raw));

		// Read the columns after the first step, since that step recompiles the statement if the schema changed.
		var columnCount = sqlite3_column_count(statement.raw);
		var columnNames = new Vector<String>(columnCount);
		for (i in 0...columnCount) {
			columnNames[i] = sqlite3_column_name(statement.raw, i);
		}

		// An error fetching the next row is kept and thrown by the next `hasNext()` or `next()` call,
		// so the row already fetched is still returned.
		// It is read when the row fails, since later calls on the connection replace the connection's error.
		var nextRowError:Null<SQLiteException> = null;

		function checkCurrent():Void {
			checkOpen();
			if (execution != thisExecution) {
				throw new SQLiteException("Iterator is out of date: its statement was reset or executed again", SQLiteResultCode.MISUSE);
			}
			if (nextRowError != null) throwStepError(nextRowError);
		}

		// Returns an Iterator, which provides hasNext() and next().
		// You can loop over this to fetch values one at a time as needed,
		// or use Lambda.array() to just get an Array of values.
		return {
			hasNext: () -> {
				checkCurrent();
				return status == SQLiteResultCode.ROW;
			},
			next: () -> {
				checkCurrent();

				switch (status) {
					case DONE:
						// We've already read the last row in the query results.
						return null;

					case ROW:
						// Read the next row in the query results.
						var data:Dynamic = {};
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
									var text:ConstPointer<Char> = ConstPointer.fromRaw(sqlite3_column_text(statement.raw, i)).reinterpret();
									var textBytes:Int = sqlite3_column_bytes(statement.raw, i);
									Reflect.setField(data, columnNames[i], NativeString.fromPointerLen(text, textBytes));
								case BLOB:
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
									throw new SQLiteException('Unknown column type ${type}', SQLiteResultCode.INTERNAL);
							}
						}
						status = step();
						if (status != SQLiteResultCode.ROW && status != SQLiteResultCode.DONE) {
							nextRowError = SQLiteException.fromConnection(owner.db.raw);
						}
						return data;
						
					case _:
						// Unreachable: errors are thrown above, before the status is read.
						throw new SQLiteException('Unexpected step result ${status}', SQLiteResultCode.INTERNAL);
				}
			}
		}
	}
}
#end
