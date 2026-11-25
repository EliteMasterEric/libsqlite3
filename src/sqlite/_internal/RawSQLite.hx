package sqlite._internal;

import cpp.Callable;
import cpp.Char;
import cpp.ConstCharStar;
import cpp.Int64;
import cpp.RawConstPointer;
import cpp.RawPointer;
import cpp.UInt32;
import cpp.UInt64;
import cpp.UInt8;

/**
 * `void (*)(void*)`: what SQLite does with bound text or blob memory. Pass `SQLITE_STATIC` or `SQLITE_TRANSIENT`.
 */
typedef RawSQLiteDestructor = Callable<RawPointer<cpp.Void>->cpp.Void>;

/**
 * `int (*)(void*, int, char**, char**)`: the per-row callback of `sqlite3_exec`, called with
 * (user data, column count, column values, column names). Return non-zero to abort. May be `null`.
 */
typedef RawSQLiteExecCallback = Callable<(RawPointer<cpp.Void>, Int, RawPointer<RawPointer<Char>>, RawPointer<RawPointer<Char>>) -> Int>;

/**
 * The native `sqlite3` connection, with externs for the SQLite C API.
 * @see `sqlite.SQLite` for the clean Haxe API.
 */
@:buildXml('
    <set name="lib_folder" value="${haxelib:libsqlite3}/lib" />
    <echo value="Using sqlite3 from: ${lib_folder}" />
    <section>
        <files id="haxe">
            <compilerflag value="-I${lib_folder}" />
            <compilerflag value="-DSQLITE_OMIT_SHARED_CACHE" />
            <file name="${lib_folder}/sqlite3.c" />
        </files>
    </section>
')
@:include("sqlite3.h")
@:native("sqlite3")
@:unreflective
extern class RawSQLite {
	// Destructor constants for binding text and blobs
	@:native("SQLITE_STATIC") static var SQLITE_STATIC:RawSQLiteDestructor;
	@:native("SQLITE_TRANSIENT") static var SQLITE_TRANSIENT:RawSQLiteDestructor;

	// Library
	@:native("sqlite3_libversion") static function sqlite3_libversion():ConstCharStar;
	@:native("sqlite3_libversion_number") static function sqlite3_libversion_number():Int;
	@:native("sqlite3_malloc64") static function sqlite3_malloc64(size:UInt64):RawPointer<cpp.Void>;
	@:native("sqlite3_free") static function sqlite3_free(ptr:RawPointer<cpp.Void>):Void;
	@:native("sqlite3_memory_used") static function sqlite3_memory_used():Int64;

	// Connections
	@:native("sqlite3_open") static function sqlite3_open(filename:ConstCharStar, db:RawPointer<RawPointer<RawSQLite>>):Int;
	@:native("sqlite3_open_v2") static function sqlite3_open_v2(filename:ConstCharStar, db:RawPointer<RawPointer<RawSQLite>>, flags:Int,
		vfs:ConstCharStar):Int;
	@:native("sqlite3_close") static function sqlite3_close(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_close_v2") static function sqlite3_close_v2(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_exec") static function sqlite3_exec(db:RawPointer<RawSQLite>, sql:ConstCharStar, callback:RawSQLiteExecCallback,
		callbackArg:RawPointer<cpp.Void>, errmsg:RawPointer<RawPointer<Char>>):Int;
	@:native("sqlite3_last_insert_rowid") static function sqlite3_last_insert_rowid(db:RawPointer<RawSQLite>):Int64;
	@:native("sqlite3_changes") static function sqlite3_changes(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_changes64") static function sqlite3_changes64(db:RawPointer<RawSQLite>):Int64;
	@:native("sqlite3_total_changes64") static function sqlite3_total_changes64(db:RawPointer<RawSQLite>):Int64;
	@:native("sqlite3_busy_timeout") static function sqlite3_busy_timeout(db:RawPointer<RawSQLite>, ms:Int):Int;
	@:native("sqlite3_get_autocommit") static function sqlite3_get_autocommit(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_interrupt") static function sqlite3_interrupt(db:RawPointer<RawSQLite>):Void;
	@:native("sqlite3_db_readonly") static function sqlite3_db_readonly(db:RawPointer<RawSQLite>, dbName:ConstCharStar):Int;
	@:native("sqlite3_db_filename") static function sqlite3_db_filename(db:RawPointer<RawSQLite>, dbName:ConstCharStar):ConstCharStar;

	// Errors
	@:native("sqlite3_errmsg") static function sqlite3_errmsg(db:RawPointer<RawSQLite>):ConstCharStar;
	@:native("sqlite3_errstr") static function sqlite3_errstr(code:Int):ConstCharStar;
	@:native("sqlite3_errcode") static function sqlite3_errcode(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_extended_errcode") static function sqlite3_extended_errcode(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_extended_result_codes") static function sqlite3_extended_result_codes(db:RawPointer<RawSQLite>, onoff:Int):Int;
	@:native("sqlite3_error_offset") static function sqlite3_error_offset(db:RawPointer<RawSQLite>):Int;

	// Statements
	@:native("sqlite3_prepare_v2") static function sqlite3_prepare_v2(db:RawPointer<RawSQLite>, sql:ConstCharStar, nbyte:Int,
		stmt:RawPointer<RawPointer<RawSQLiteStatement>>, tail:RawPointer<ConstCharStar>):Int;
	@:native("sqlite3_step") static function sqlite3_step(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_reset") static function sqlite3_reset(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_finalize") static function sqlite3_finalize(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_sql") static function sqlite3_sql(stmt:RawPointer<RawSQLiteStatement>):ConstCharStar;
	@:native("sqlite3_expanded_sql") static function sqlite3_expanded_sql(stmt:RawPointer<RawSQLiteStatement>):RawPointer<Char>;
	@:native("sqlite3_stmt_readonly") static function sqlite3_stmt_readonly(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_stmt_busy") static function sqlite3_stmt_busy(stmt:RawPointer<RawSQLiteStatement>):Int;

	// Binding parameters (indexes start at 1)
	@:native("sqlite3_bind_int") static function sqlite3_bind_int(stmt:RawPointer<RawSQLiteStatement>, index:Int, value:Int):Int;
	@:native("sqlite3_bind_int64") static function sqlite3_bind_int64(stmt:RawPointer<RawSQLiteStatement>, index:Int, value:Int64):Int;
	@:native("sqlite3_bind_double") static function sqlite3_bind_double(stmt:RawPointer<RawSQLiteStatement>, index:Int, value:Float):Int;
	@:native("sqlite3_bind_null") static function sqlite3_bind_null(stmt:RawPointer<RawSQLiteStatement>, index:Int):Int;
	@:native("sqlite3_bind_zeroblob") static function sqlite3_bind_zeroblob(stmt:RawPointer<RawSQLiteStatement>, index:Int, nbyte:Int):Int;
	@:native("sqlite3_bind_text") static function sqlite3_bind_text(stmt:RawPointer<RawSQLiteStatement>, index:Int, text:ConstCharStar,
		nbyte:Int, destructor:RawSQLiteDestructor):Int;
	@:native("sqlite3_bind_text64") static function sqlite3_bind_text64(stmt:RawPointer<RawSQLiteStatement>, index:Int, text:ConstCharStar,
		nbyte:UInt64, destructor:RawSQLiteDestructor, encoding:UInt8):Int;
	@:native("sqlite3_bind_blob") static function sqlite3_bind_blob(stmt:RawPointer<RawSQLiteStatement>, index:Int,
		data:RawConstPointer<cpp.Void>, nbyte:Int, destructor:RawSQLiteDestructor):Int;
	@:native("sqlite3_bind_blob64") static function sqlite3_bind_blob64(stmt:RawPointer<RawSQLiteStatement>, index:Int,
		data:RawConstPointer<cpp.Void>, nbyte:UInt64, destructor:RawSQLiteDestructor):Int;
	@:native("sqlite3_clear_bindings") static function sqlite3_clear_bindings(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_bind_parameter_count") static function sqlite3_bind_parameter_count(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_bind_parameter_index") static function sqlite3_bind_parameter_index(stmt:RawPointer<RawSQLiteStatement>,
		name:ConstCharStar):Int;
	@:native("sqlite3_bind_parameter_name") static function sqlite3_bind_parameter_name(stmt:RawPointer<RawSQLiteStatement>,
		index:Int):ConstCharStar;

	// Result columns (indexes start at 0)
	@:native("sqlite3_column_count") static function sqlite3_column_count(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_column_name") static function sqlite3_column_name(stmt:RawPointer<RawSQLiteStatement>, index:Int):ConstCharStar;
	@:native("sqlite3_column_decltype") static function sqlite3_column_decltype(stmt:RawPointer<RawSQLiteStatement>, index:Int):ConstCharStar;
	@:native("sqlite3_column_type") static function sqlite3_column_type(stmt:RawPointer<RawSQLiteStatement>, index:Int):Int;
	@:native("sqlite3_column_value") static function sqlite3_column_value(stmt:RawPointer<RawSQLiteStatement>, index:Int):RawPointer<RawSQLiteValue>;
	@:native("sqlite3_column_int") static function sqlite3_column_int(stmt:RawPointer<RawSQLiteStatement>, index:Int):Int;
	@:native("sqlite3_column_int64") static function sqlite3_column_int64(stmt:RawPointer<RawSQLiteStatement>, index:Int):Int64;
	@:native("sqlite3_column_double") static function sqlite3_column_double(stmt:RawPointer<RawSQLiteStatement>, index:Int):Float;
	@:native("sqlite3_column_text") static function sqlite3_column_text(stmt:RawPointer<RawSQLiteStatement>, index:Int):RawConstPointer<UInt8>;
	@:native("sqlite3_column_blob") static function sqlite3_column_blob(stmt:RawPointer<RawSQLiteStatement>, index:Int):RawConstPointer<cpp.Void>;
	@:native("sqlite3_column_bytes") static function sqlite3_column_bytes(stmt:RawPointer<RawSQLiteStatement>, index:Int):Int;

	// Values
	@:native("sqlite3_value_type") static function sqlite3_value_type(value:RawPointer<RawSQLiteValue>):Int;
	@:native("sqlite3_value_int") static function sqlite3_value_int(value:RawPointer<RawSQLiteValue>):Int;
	@:native("sqlite3_value_double") static function sqlite3_value_double(value:RawPointer<RawSQLiteValue>):Float;
	@:native("sqlite3_value_text") static function sqlite3_value_text(value:RawPointer<RawSQLiteValue>):RawConstPointer<UInt8>;
	@:native("sqlite3_value_blob") static function sqlite3_value_blob(value:RawPointer<RawSQLiteValue>):RawConstPointer<cpp.Void>;
	@:native("sqlite3_value_bytes") static function sqlite3_value_bytes(value:RawPointer<RawSQLiteValue>):Int;
	@:native("sqlite3_value_free") static function sqlite3_value_free(value:RawPointer<RawSQLiteValue>):Void;

	// Online backup
	@:native("sqlite3_backup_init") static function sqlite3_backup_init(dest:RawPointer<RawSQLite>, destName:ConstCharStar,
		source:RawPointer<RawSQLite>, sourceName:ConstCharStar):RawPointer<RawSQLiteBackup>;
	@:native("sqlite3_backup_step") static function sqlite3_backup_step(backup:RawPointer<RawSQLiteBackup>, pages:Int):Int;
	@:native("sqlite3_backup_finish") static function sqlite3_backup_finish(backup:RawPointer<RawSQLiteBackup>):Int;

	// Incremental blob I/O
	@:native("sqlite3_blob_open") static function sqlite3_blob_open(db:RawPointer<RawSQLite>, dbName:ConstCharStar, table:ConstCharStar,
		column:ConstCharStar, row:Int64, flags:Int, blob:RawPointer<RawPointer<RawSQLiteBlob>>):Int;
	@:native("sqlite3_blob_read") static function sqlite3_blob_read(blob:RawPointer<RawSQLiteBlob>, buffer:RawPointer<cpp.Void>, nbyte:Int,
		offset:Int):Int;
	@:native("sqlite3_blob_write") static function sqlite3_blob_write(blob:RawPointer<RawSQLiteBlob>, data:RawConstPointer<cpp.Void>,
		nbyte:Int, offset:Int):Int;
	@:native("sqlite3_blob_bytes") static function sqlite3_blob_bytes(blob:RawPointer<RawSQLiteBlob>):Int;
	@:native("sqlite3_blob_close") static function sqlite3_blob_close(blob:RawPointer<RawSQLiteBlob>):Int;

	// Serialization
	@:native("SQLITE_SERIALIZE_NOCOPY") static var SQLITE_SERIALIZE_NOCOPY:Int;
	@:native("SQLITE_DESERIALIZE_FREEONCLOSE") static var SQLITE_DESERIALIZE_FREEONCLOSE:Int;
	@:native("SQLITE_DESERIALIZE_RESIZEABLE") static var SQLITE_DESERIALIZE_RESIZEABLE:Int;
	@:native("SQLITE_DESERIALIZE_READONLY") static var SQLITE_DESERIALIZE_READONLY:Int;
	@:native("sqlite3_serialize") static function sqlite3_serialize(db:RawPointer<RawSQLite>, schema:ConstCharStar, size:RawPointer<Int64>,
		flags:UInt32):RawPointer<UInt8>;
	@:native("sqlite3_deserialize") static function sqlite3_deserialize(db:RawPointer<RawSQLite>, schema:ConstCharStar, data:RawPointer<UInt8>,
		dbSize:Int64, bufferSize:Int64, flags:UInt32):Int;
}
