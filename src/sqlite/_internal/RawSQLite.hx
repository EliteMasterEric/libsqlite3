package sqlite._internal;

import cpp.ConstCharStar;
import cpp.RawConstPointer;
import cpp.RawPointer;

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
	// Connections
	@:native("sqlite3_open") static function sqlite3_open(filename:ConstCharStar, db:RawPointer<RawPointer<RawSQLite>>):Int;
	@:native("sqlite3_close") static function sqlite3_close(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_last_insert_rowid") static function sqlite3_last_insert_rowid(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_changes") static function sqlite3_changes(db:RawPointer<RawSQLite>):Int;

	// Errors
	@:native("sqlite3_errmsg") static function sqlite3_errmsg(db:RawPointer<RawSQLite>):ConstCharStar;
	@:native("sqlite3_errstr") static function sqlite3_errstr(code:Int):ConstCharStar;
	@:native("sqlite3_errcode") static function sqlite3_errcode(db:RawPointer<RawSQLite>):Int;
	@:native("sqlite3_extended_errcode") static function sqlite3_extended_errcode(db:RawPointer<RawSQLite>):Int;

	// Statements
	@:native("sqlite3_prepare_v2") static function sqlite3_prepare_v2(db:RawPointer<RawSQLite>, sql:ConstCharStar, nbyte:Int,
		stmt:RawPointer<RawPointer<RawSQLiteStatement>>, tail:RawPointer<ConstCharStar>):Int;
	@:native("sqlite3_step") static function sqlite3_step(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_reset") static function sqlite3_reset(stmt:RawPointer<RawSQLiteStatement>):Void;
	@:native("sqlite3_finalize") static function sqlite3_finalize(stmt:RawPointer<RawSQLiteStatement>):Void;

	// Result columns
	@:native("sqlite3_column_count") static function sqlite3_column_count(stmt:RawPointer<RawSQLiteStatement>):Int;
	@:native("sqlite3_column_name") static function sqlite3_column_name(stmt:RawPointer<RawSQLiteStatement>, index:Int):ConstCharStar;
	@:native("sqlite3_column_type") static function sqlite3_column_type(stmt:RawPointer<RawSQLiteStatement>, index:Int):Int;
	@:native("sqlite3_column_value") static function sqlite3_column_value(stmt:RawPointer<RawSQLiteStatement>, index:Int):RawPointer<RawSQLiteValue>;
	@:native("sqlite3_column_int") static function sqlite3_column_int(stmt:RawPointer<RawSQLiteStatement>, index:Int):Int;
	@:native("sqlite3_column_double") static function sqlite3_column_double(stmt:RawPointer<RawSQLiteStatement>, index:Int):Float;
	@:native("sqlite3_column_blob") static function sqlite3_column_blob(stmt:RawPointer<RawSQLiteStatement>, index:Int):RawConstPointer<cpp.Void>;
	@:native("sqlite3_column_bytes") static function sqlite3_column_bytes(stmt:RawPointer<RawSQLiteStatement>, index:Int):Int;

	// Values
	@:native("sqlite3_value_type") static function sqlite3_value_type(value:RawPointer<RawSQLiteValue>):Int;
	@:native("sqlite3_value_int") static function sqlite3_value_int(value:RawPointer<RawSQLiteValue>):Int;
	@:native("sqlite3_value_double") static function sqlite3_value_double(value:RawPointer<RawSQLiteValue>):Float;
	@:native("sqlite3_value_text") static function sqlite3_value_text(value:RawPointer<RawSQLiteValue>):ConstCharStar;
	@:native("sqlite3_value_blob") static function sqlite3_value_blob(value:RawPointer<RawSQLiteValue>):RawPointer<Void>;
	@:native("sqlite3_value_bytes") static function sqlite3_value_bytes(value:RawPointer<RawSQLiteValue>):Int;
	@:native("sqlite3_value_free") static function sqlite3_value_free(value:RawPointer<RawSQLiteValue>):Void;
}
