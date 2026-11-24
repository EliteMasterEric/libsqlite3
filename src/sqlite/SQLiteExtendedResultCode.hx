package sqlite;

import sqlite.SQLiteResultCode;

/**
 * SQLite's extended result codes, as returned by `sqlite3_extended_errcode`.
 *
 * The lower 8 bits correspond to an SQLiteResultCode, while the upper bits give more detail.
 * The value will just be an SQLiteResultCode if SQLite doesn't have more specific information.
 *
 * @see https://www.sqlite.org/rescode.html#extrc
 */
enum abstract SQLiteExtendedResultCode(Int) from Int to Int {
	// Basic result codes.
	var OK = 0;
	var ERROR = 1;
	var INTERNAL = 2;
	var PERM = 3;
	var ABORT = 4;
	var BUSY = 5;
	var LOCKED = 6;
	var NOMEM = 7;
	var READONLY = 8;
	var INTERRUPT = 9;
	var IOERR = 10;
	var CORRUPT = 11;
	var NOTFOUND = 12;
	var FULL = 13;
	var CANTOPEN = 14;
	var PROTOCOL = 15;
	var EMPTY = 16;
	var SCHEMA = 17;
	var TOOBIG = 18;
	var CONSTRAINT = 19;
	var MISMATCH = 20;
	var MISUSE = 21;
	var NOLFS = 22;
	var AUTH = 23;
	var FORMAT = 24;
	var RANGE = 25;
	var NOTADB = 26;
	var NOTICE = 27;
	var WARNING = 28;
	var ROW = 100;
	var DONE = 101;

	// Extended result codes.
	
	var ERROR_MISSING_COLLSEQ = 257;
	var ERROR_RETRY = 513;
	var ERROR_SNAPSHOT = 769;
	var ERROR_RESERVESIZE = 1025;
	var ERROR_KEY = 1281;
	var ERROR_UNABLE = 1537;

	var IOERR_READ = 266;
	var IOERR_SHORT_READ = 522;
	var IOERR_WRITE = 778;
	var IOERR_FSYNC = 1034;
	var IOERR_DIR_FSYNC = 1290;
	var IOERR_TRUNCATE = 1546;
	var IOERR_FSTAT = 1802;
	var IOERR_UNLOCK = 2058;
	var IOERR_RDLOCK = 2314;
	var IOERR_DELETE = 2570;
	var IOERR_BLOCKED = 2826;
	var IOERR_NOMEM = 3082;
	var IOERR_ACCESS = 3338;
	var IOERR_CHECKRESERVEDLOCK = 3594;
	var IOERR_LOCK = 3850;
	var IOERR_CLOSE = 4106;
	var IOERR_DIR_CLOSE = 4362;
	var IOERR_SHMOPEN = 4618;
	var IOERR_SHMSIZE = 4874;
	var IOERR_SHMLOCK = 5130;
	var IOERR_SHMMAP = 5386;
	var IOERR_SEEK = 5642;
	var IOERR_DELETE_NOENT = 5898;
	var IOERR_MMAP = 6154;
	var IOERR_GETTEMPPATH = 6410;
	var IOERR_CONVPATH = 6666;
	var IOERR_VNODE = 6922;
	var IOERR_AUTH = 7178;
	var IOERR_BEGIN_ATOMIC = 7434;
	var IOERR_COMMIT_ATOMIC = 7690;
	var IOERR_ROLLBACK_ATOMIC = 7946;
	var IOERR_DATA = 8202;
	var IOERR_CORRUPTFS = 8458;
	var IOERR_IN_PAGE = 8714;
	var IOERR_BADKEY = 8970;
	var IOERR_CODEC = 9226;

	var LOCKED_SHAREDCACHE = 262;
	var LOCKED_VTAB = 518;

	var BUSY_RECOVERY = 261;
	var BUSY_SNAPSHOT = 517;
	var BUSY_TIMEOUT = 773;

	var CANTOPEN_NOTEMPDIR = 270;
	var CANTOPEN_ISDIR = 526;
	var CANTOPEN_FULLPATH = 782;
	var CANTOPEN_CONVPATH = 1038;
	var CANTOPEN_DIRTYWAL = 1294;
	var CANTOPEN_SYMLINK = 1550;

	var CORRUPT_VTAB = 267;
	var CORRUPT_SEQUENCE = 523;
	var CORRUPT_INDEX = 779;

	var READONLY_RECOVERY = 264;
	var READONLY_CANTLOCK = 520;
	var READONLY_ROLLBACK = 776;
	var READONLY_DBMOVED = 1032;
	var READONLY_CANTINIT = 1288;
	var READONLY_DIRECTORY = 1544;

	var ABORT_ROLLBACK = 516;

	var CONSTRAINT_CHECK = 275;
	var CONSTRAINT_COMMITHOOK = 531;
	var CONSTRAINT_FOREIGNKEY = 787;
	var CONSTRAINT_FUNCTION = 1043;
	var CONSTRAINT_NOTNULL = 1299;
	var CONSTRAINT_PRIMARYKEY = 1555;
	var CONSTRAINT_TRIGGER = 1811;
	var CONSTRAINT_UNIQUE = 2067;
	var CONSTRAINT_VTAB = 2323;
	var CONSTRAINT_ROWID = 2579;
	var CONSTRAINT_PINNED = 2835;
	var CONSTRAINT_DATATYPE = 3091;

	var NOTICE_RECOVER_WAL = 283;
	var NOTICE_RECOVER_ROLLBACK = 539;
	var NOTICE_RBU = 795;

	var WARNING_AUTOINDEX = 284;

	var AUTH_USER = 279;

	var OK_LOAD_PERMANENTLY = 256;
	var OK_SYMLINK = 512;

	public function toResultCode():SQLiteResultCode {
		// NOTE: Do NOT auto-cast with @:to(SQLiteResultCode), since you lose data on implicit casts.
		// Truncate to the first 8 bits.
		return this & 0xFF;
	}
}
