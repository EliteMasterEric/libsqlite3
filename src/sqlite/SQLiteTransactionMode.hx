package sqlite;

/**
 * How a transaction from `SQLiteDatabase.begin()` or `transaction()` takes its locks.
 * @see https://sqlite.org/lang_transaction.html
 */
enum abstract SQLiteTransactionMode(String)
{
  /**
   * Takes no lock until the first read or write.
   * A write can then fail with `BUSY` if another connection is writing.
   */
  var DEFERRED = "DEFERRED";

  /**
   * Starts a write right away, so other connections can't write until it ends.
   * Use this to avoid `BUSY` part way through a transaction that writes.
   */
  var IMMEDIATE = "IMMEDIATE";

  /**
   * Like `IMMEDIATE`. In WAL mode the two are the same;
   * in other journal modes, other connections can't read either.
   */
  var EXCLUSIVE = "EXCLUSIVE";
}
