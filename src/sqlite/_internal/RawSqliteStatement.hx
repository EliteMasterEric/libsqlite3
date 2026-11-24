package sqlite._internal;

/**
 * The native `sqlite3_stmt` (a prepared statement).
 */
@:include("sqlite3.h")
@:native("sqlite3_stmt")
@:unreflective
extern class RawSqliteStatement {}
