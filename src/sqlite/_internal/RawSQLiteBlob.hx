package sqlite._internal;

/**
 * The native `sqlite3_blob` (an open handle for incremental blob I/O).
 */
@:include("sqlite3.h")
@:native("sqlite3_blob")
@:unreflective
extern class RawSQLiteBlob
{
}
