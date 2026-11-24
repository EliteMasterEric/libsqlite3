package sqlite;

#if cpp
import cpp.Char;
import cpp.ConstPointer;
import cpp.NativeString;
import cpp.UInt8;
import cpp.RawConstPointer;
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

		var result = sqlite3_reset(statement.raw);
		
		var alreadyThrown = stepErrorThrown;
		stepErrorThrown = false;
		if (result != SQLite.OK && !alreadyThrown) {
			throw new Exception(sqlite3_errmsg(owner.db.raw));
		}

		return this;
	}

	public function bindInt(index:Int, value:Int):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var result = sqlite3_bind_int(statement.raw, index, value));
		if (result != SQLite.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));

		return this;
	}

	public function bindInt64(index:Int, value:Int64):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var result = sqlite3_bind_int64(statement.raw, index, value));
		if (result != SQLite.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));

		return this;
	}

	public function bindFloat(index:Int, value:Float):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var result = sqlite3_bind_double(statement.raw, index, value));
		if (result != SQLite.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));

		return this;
	}

	public function bindString(index:Int, value:String):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		// Bind the full UTF-8 encoding with its length, so text containing NUL characters is not cut short.
		// (The implicit `ConstCharStar` conversion stops at the first NUL for non-ASCII strings.)
		var utf8 = Bytes.ofString(value);
		if (utf8.length == 0) {
			// A NULL pointer would bind SQL NULL, so pass a literal for the empty string.
			var result = sqlite3_bind_text(statement.raw, index, "", 0, SQLITE_TRANSIENT);
			if (result != SQLite.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));
		} else {
			var p:Pointer<Char> = NativeArray.address(utf8.getData(), 0).reinterpret();
			var result = sqlite3_bind_text(statement.raw, index, cast p.raw, utf8.length, SQLITE_TRANSIENT);
			if (result != SQLite.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));
		}
		return this;
	}

	public function bindBytes(index:Int, value:Bytes):SQLiteStatement {
		if (statement == null) throw new Exception("Statement is closed");

		var len = value.length;
		var p:Pointer<cpp.Void> = NativeArray.address(value.getData(), 0).reinterpret();
		var result = sqlite3_bind_blob(statement.raw, index, p.raw, len, SQLITE_TRANSIENT);
		if (result != SQLite.OK) throw new Exception(sqlite3_errmsg(owner.db.raw));
		return this;
	}

	public function executeStatement() {
		if (statement == null) throw new Exception("Statement is closed");

		var result = sqlite3_step(statement.raw);
		if (result != SQLite.DONE) {
			stepErrorThrown = true;
			throw new Exception(sqlite3_errmsg(owner.db.raw));
		}
	}

	public function executeQuery():Iterator<Dynamic> {
		if (statement == null) throw new Exception("Statement is closed");

		var columnCount = sqlite3_column_count(statement.raw);
		var columnNames = new Vector<String>(columnCount);
		for (i in 0...columnCount) {
			columnNames[i] = sqlite3_column_name(statement.raw, i);
		}

		var status = sqlite3_step(statement.raw);

		return {
			hasNext: () -> status == SQLite.ROW,
			next: () -> {
				if (statement == null) throw new Exception("Statement is closed");

				switch (status) {
					case SQLite.DONE:
						return null;
					case SQLite.ROW:
						var data = {};
						for (i in 0...columnCount) {
							var type = sqlite3_column_type(statement.raw, i);
							switch (type) {
								case SQLite.INTEGER:
									// An `Int` when the value fits in 32 bits, otherwise an `Int64`.
									var value:Int64 = sqlite3_column_int64(statement.raw, i);
									if (value.high == value.low >> 31) {
										Reflect.setField(data, columnNames[i], value.low);
									} else {
										Reflect.setField(data, columnNames[i], value);
									}
								case SQLite.FLOAT:
									Reflect.setField(data, columnNames[i], sqlite3_column_double(statement.raw, i));
								case SQLite.TEXT:
									// Read the byte count after the text, as SQLite recommends, so embedded NULs are kept.
									var text:ConstPointer<Char> = ConstPointer.fromRaw(sqlite3_column_text(statement.raw, i)).reinterpret();
									var textBytes:Int = sqlite3_column_bytes(statement.raw, i);
									Reflect.setField(data, columnNames[i], NativeString.fromPointerLen(text, textBytes));
								case SQLite.BLOB:
									var rawData:RawConstPointer<cpp.Void> = sqlite3_column_blob(statement.raw, i);
									var p:ConstPointer<cpp.Void> = ConstPointer.fromRaw(rawData);
									var size:Int = sqlite3_column_bytes(statement.raw, i);
									var bytesData:Array<UInt8> = NativeArray.create(size);
									NativeArray.setData(bytesData, p.reinterpret(), size);
									var bytes:Bytes = Bytes.ofData(bytesData);
									var bytesCopy:Bytes = Bytes.alloc(size); // need to maybe a copy, gc'd or freed maybe?
									bytesCopy.blit(0, bytes, 0, size);
									Reflect.setField(data, columnNames[i], bytesCopy);
								case SQLite.NULL:
									Reflect.setField(data, columnNames[i], null);
								case _:
									throw new Exception('Type error ${type}');
							}
						}
						status = sqlite3_step(statement.raw);
						return data;
					case _:
						throw new Exception('Cursor error ${status}');
				}
			}
		}
	}
}
#end
