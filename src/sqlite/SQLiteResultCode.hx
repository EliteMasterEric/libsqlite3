package sqlite;

import sqlite.SQLiteExtendedResultCode;

/**
 * SQLite's primary result codes. `sqlite3_*` functions return these.
 * Can indicate success or a specific type of failure.
 *
 * @see https://www.sqlite.org/rescode.html
 */
enum abstract SQLiteResultCode(Int) from Int to Int
{
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

  /**
   * `sqlite3_step` produced a row of results.
   */
  var ROW = 100;

  /**
   * `sqlite3_step` finished executing the statement.
   */
  var DONE = 101;

  @:to(SQLiteExtendedResultCode)
  public function toExtendedResultCode():SQLiteExtendedResultCode
  {
    // NOTE: This doesn't include any of the extended info!
    return this;
  }
}
