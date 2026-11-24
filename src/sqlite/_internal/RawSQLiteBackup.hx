package sqlite._internal;

/**
 * The native `sqlite3_backup` (an online backup in progress).
 */
@:include("sqlite3.h")
@:native("sqlite3_backup")
@:unreflective
extern class RawSQLiteBackup {}
