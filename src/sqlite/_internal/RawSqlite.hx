package sqlite._internal;

import cpp.ConstCharStar;
import cpp.RawConstPointer;
import cpp.RawPointer;

/**
 * The native `sqlite3` connection, with externs for the SQLite C API.
 * @see `sqlite.Sqlite` for the clean Haxe API.
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
extern class RawSqlite {
	// Connections
	@:native("sqlite3_open") static function sqlite3_open(filename:ConstCharStar, db:RawPointer<RawPointer<RawSqlite>>):Int;
	@:native("sqlite3_close") static function sqlite3_close(db:RawPointer<RawSqlite>):Void;
	@:native("sqlite3_last_insert_rowid") static function sqlite3_last_insert_rowid(db:RawPointer<RawSqlite>):Int;
	@:native("sqlite3_changes") static function sqlite3_changes(db:RawPointer<RawSqlite>):Int;

	// Errors
	@:native("sqlite3_errmsg") static function sqlite3_errmsg(db:RawPointer<RawSqlite>):ConstCharStar;
	@:native("sqlite3_errstr") static function sqlite3_errstr(code:Int):ConstCharStar;
	@:native("sqlite3_errcode") static function sqlite3_errcode(db:RawPointer<RawSqlite>):Int;
	@:native("sqlite3_extended_errcode") static function sqlite3_extended_errcode(db:RawPointer<RawSqlite>):Int;

	// Statements
	@:native("sqlite3_prepare_v2") static function sqlite3_prepare_v2(db:RawPointer<RawSqlite>, sql:ConstCharStar, nbyte:Int,
		stmt:RawPointer<RawPointer<RawSqliteStatement>>, tail:RawPointer<ConstCharStar>):Int;
	@:native("sqlite3_step") static function sqlite3_step(stmt:RawPointer<RawSqliteStatement>):Int;
	@:native("sqlite3_reset") static function sqlite3_reset(stmt:RawPointer<RawSqliteStatement>):Void;
	@:native("sqlite3_finalize") static function sqlite3_finalize(stmt:RawPointer<RawSqliteStatement>):Void;

	// Result columns
	@:native("sqlite3_column_count") static function sqlite3_column_count(stmt:RawPointer<RawSqliteStatement>):Int;
	@:native("sqlite3_column_name") static function sqlite3_column_name(stmt:RawPointer<RawSqliteStatement>, index:Int):ConstCharStar;
	@:native("sqlite3_column_type") static function sqlite3_column_type(stmt:RawPointer<RawSqliteStatement>, index:Int):Int;
	@:native("sqlite3_column_value") static function sqlite3_column_value(stmt:RawPointer<RawSqliteStatement>, index:Int):RawPointer<RawSqliteValue>;
	@:native("sqlite3_column_int") static function sqlite3_column_int(stmt:RawPointer<RawSqliteStatement>, index:Int):Int;
	@:native("sqlite3_column_double") static function sqlite3_column_double(stmt:RawPointer<RawSqliteStatement>, index:Int):Float;
	@:native("sqlite3_column_blob") static function sqlite3_column_blob(stmt:RawPointer<RawSqliteStatement>, index:Int):RawConstPointer<cpp.Void>;
	@:native("sqlite3_column_bytes") static function sqlite3_column_bytes(stmt:RawPointer<RawSqliteStatement>, index:Int):Int;

	// Values
	@:native("sqlite3_value_type") static function sqlite3_value_type(value:RawPointer<RawSqliteValue>):Int;
	@:native("sqlite3_value_int") static function sqlite3_value_int(value:RawPointer<RawSqliteValue>):Int;
	@:native("sqlite3_value_double") static function sqlite3_value_double(value:RawPointer<RawSqliteValue>):Float;
	@:native("sqlite3_value_text") static function sqlite3_value_text(value:RawPointer<RawSqliteValue>):ConstCharStar;
	@:native("sqlite3_value_blob") static function sqlite3_value_blob(value:RawPointer<RawSqliteValue>):RawPointer<Void>;
	@:native("sqlite3_value_bytes") static function sqlite3_value_bytes(value:RawPointer<RawSqliteValue>):Int;
	@:native("sqlite3_value_free") static function sqlite3_value_free(value:RawPointer<RawSqliteValue>):Void;
}
