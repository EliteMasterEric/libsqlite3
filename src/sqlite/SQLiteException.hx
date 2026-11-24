package sqlite;

#if cpp
import cpp.RawPointer;
import haxe.Exception;
import sqlite._internal.RawSQLite;
import sqlite._internal.RawSQLite.*;

/**
 * An exception representing an error from SQLite.
 */
@:unreflective
class SQLiteException extends Exception {
	/**
	 * The primary result code, such as `SQLiteResultCode.CONSTRAINT` or `SQLiteResultCode.BUSY`.
	 */
	public final code:SQLiteResultCode;

	/**
	 * The extended result code. Can provide more detailed information about an error.
	 * Equal to `code` when there is no more specific value.
	 * @see https://www.sqlite.org/rescode.html#extrc
	 */
	public final extendedCode:SQLiteExtendedResultCode;

	/**
	 * @param message The error message.
	 * @param code The primary result code.
	 * @param extendedCode The extended result code. Defaults to `code`.
	 */
	public function new(message:String, code:SQLiteResultCode, ?extendedCode:SQLiteExtendedResultCode) {
		super(message);
		this.code = code;
		this.extendedCode = extendedCode ?? code.toExtendedResultCode();
	}

	/**
	 * References the connection and produces an exception,
	 * with that connection's most recent error code and error message.
	 */
	@:allow(sqlite)
	private static function fromConnection(db:RawPointer<RawSQLite>):SQLiteException {
		var extendedCode:SQLiteExtendedResultCode = sqlite3_extended_errcode(db);
		return new SQLiteException(sqlite3_errmsg(db), extendedCode.toResultCode(), extendedCode);
	}
}
#end
