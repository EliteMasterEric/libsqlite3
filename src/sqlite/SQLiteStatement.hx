package sqlite;

import cpp.ConstPointer;
import cpp.UInt8;
import cpp.RawConstPointer;
import cpp.NativeArray;
import haxe.io.BytesData;
import haxe.io.Bytes;
import haxe.Exception;
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

	private function new(owner:SQLiteDatabase, statement:Pointer<RawSQLiteStatement>) {
		super();
		this.owner = owner;
		this.statement = statement;
	}

	/**
	 * Runs only once the owning database is unreachable too, since the database keeps every open statement.
	 * Touches no other GC object, because the database may already be finalized.
	 */
	public override function finalize() {
		if (statement != null) {
			sqlite3_finalize(statement.raw);
			statement = null;
		}
		super.finalize();
	}

	/**
	 * Finalizes the statement and frees its resources. It cannot be used after this.
	 * Does nothing if the statement is already closed. `SQLiteDatabase.close()` closes all open statements.
	 */
	public function close():Void {
		if (statement == null) return;

		sqlite3_finalize(statement.raw);
		owner.onStatementClosed(this);
		this.owner = null;
		this.statement = null;
	}

	public function reset():SQLiteStatement {
		sqlite3_reset(statement.raw);
		return this;
	}

	public function bindInt(index:Int, value:Int):SQLiteStatement {
		untyped __cpp__("sqlite3_bind_int({0}, {1}, {2})", statement, index, value);
		return this;
	}

	public function bindFloat(index:Int, value:Float):SQLiteStatement {
		untyped __cpp__("sqlite3_bind_double({0}, {1}, {2})", statement, index, value);
		return this;
	}

	public function bindString(index:Int, value:String):SQLiteStatement {
		untyped __cpp__("sqlite3_bind_text({0}, {1}, {2}, -1, SQLITE_TRANSIENT)", statement, index, value);
		return this;
	}

	public function bindBytes(index:Int, value:Bytes):SQLiteStatement {
		var len = value.length;
		var p = NativeArray.address(value.getData(), 0);
		untyped __cpp__("sqlite3_bind_blob({0}, {1}, {2}, {3}, SQLITE_TRANSIENT)", statement, index, p, len);
		return this;
	}

	public function executeStatement() {
		var i = sqlite3_step(statement.raw);
		if (i != SQLite.DONE) {
			throw new Exception(sqlite3_errmsg(owner.db.raw));
		}
	}

	public function executeQuery():Iterator<Dynamic> {
		var columnCount = sqlite3_column_count(statement.raw);
		var columnNames = new Vector<String>(columnCount);
		for (i in 0...columnCount) {
			columnNames[i] = sqlite3_column_name(statement.raw, i);
		}

		var status = sqlite3_step(statement.raw);

		return {
			hasNext: () -> status == SQLite.ROW,
			next: () -> {
				switch (status) {
					case SQLite.DONE:
						return null;
					case SQLite.ROW:
						var data = {};
						for (i in 0...columnCount) {
							var type = sqlite3_column_type(statement.raw, i);
							switch (type) {
								case SQLite.INTEGER:
									Reflect.setField(data, columnNames[i], sqlite3_column_int(statement.raw, i));
								case SQLite.FLOAT:
									Reflect.setField(data, columnNames[i], sqlite3_column_double(statement.raw, i));
								case SQLite.TEXT:
									var s:String = untyped __cpp__("(const char*)sqlite3_column_text({0}, {1})", statement.raw, i);
									Reflect.setField(data, columnNames[i], s);
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
