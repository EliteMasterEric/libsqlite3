package sqlite;

#if cpp
import cpp.Callable;
import cpp.Char;
import cpp.ConstCharStar;
import cpp.NativeArray;
import cpp.Pointer;
import cpp.RawPointer;
import cpp.Stdlib;
import cpp.UInt8;
import cpp.vm.Gc;
import cpp.vm.WeakRef;
import haxe.Exception;
import haxe.Int64;
import haxe.io.Bytes;
import sqlite._internal.RawSQLite;
import sqlite._internal.RawSQLite.*;
import sqlite._internal.RawSQLiteStatement;

/**
 * Represents an SQLite database that is currently loaded.
 * 
 * Call `SQLiteDatabase.prepare(sql)` to create a prepared statement, bind values to it, then execute the query.
 */
@:unreflective
@:allow(sqlite.SQLiteStatement)
class SQLiteDatabase
{
  /**
   * The C extern to interact with the SQLite database.
   */
  private var db:Pointer<RawSQLite>;

  /**
   * Maintain weak references to the statements on this connection that are still open.
   * `close()` needs to ensure all statements are finalized.
   * Entries that have already been closed and cleaned up are ignored.
   */
  private var statements:Array<WeakRef<SQLiteStatement>> = [];

  /**
   * Calling `prepare()` cleans up the list only once `statements` reaches this length.
   */
  private var pruneLength:Int = MIN_PRUNE_LENGTH;

  private static inline final MIN_PRUNE_LENGTH:Int = 16;

  /**
   * Use `SQLite.open(path)` to connect to a database.
   */
  @:allow(sqlite.SQLite)
  private function new(db:Pointer<RawSQLite>)
  {
    this.db = db;
    // Set a function to call when garbage collecting this object.
    Gc.setFinalizer(this, Callable.fromStaticFunction(onCollected));
  }

  /**
   * Guarantee the extern statement gets finalized and cleaned up
   * when garbage collecting this object.
   */
  @:void
  private static function onCollected(database:SQLiteDatabase):Void
  {
    if (database.db != null)
    {
      sqlite3_close_v2(database.db.raw);
      database.db = null;
    }
  }

  /**
   * Finalizes every open statement of this database, then closes the connection.
   */
  public function close():Void
  {
    if (db == null) return;

    // Close each remaining unclosed statement.
    // onStatementClosed modifies this in place while we work, so we need to iterate a copy.
    for (ref in statements.copy())
    {
      var statement = ref.get();
      if (statement != null) statement.close();
    }
    statements = [];

    var result:SQLiteResultCode = sqlite3_close_v2(db.raw);
    if (result != SQLiteResultCode.OK)
    {
      // Throw an error if SQLite can't close the connection.
      throw SQLiteException.fromConnection(db.raw);
    }

    db = null;
  }

  /**
   * Prepare a single SQL statement, to bind arguments and execute.
   * NOTE: Only allows one line of SQL. Use `exec()` to run multiple statements at once (but without being able to bind values).
   * NOTE: Since this compiles a statement, you should store and reuse it (with `reset()` and `clearBindings()`) if you plan to run it later.
   * 
   * @param sql The statement to prepare.
   * @return An `SQLiteStatement` that can be executed later.
   */
  public function prepare(sql:String):SQLiteStatement
  {
    checkOpen();

    // Pass SQLite the raw bytes of the string to ensure strings containing NULL are handled correctly.
    var utf8 = Bytes.ofString(sql);
    var length = utf8.length;
    if (length == 0) throw new SQLiteException("No SQL statement to prepare", SQLiteResultCode.MISUSE);
    var start:Pointer<Char> = NativeArray.address(utf8.getData(), 0).reinterpret();

    var rawStatement:RawPointer<RawSQLiteStatement> = null;
    var tail:ConstCharStar = null;
    var result:SQLiteResultCode = sqlite3_prepare_v2(db.raw, cast start.raw, length, RawPointer.addressOf(rawStatement), RawPointer.addressOf(tail));
    if (result != SQLiteResultCode.OK)
    {
      throw SQLiteException.fromConnection(db.raw);
    }

    // SQLite returns `null` if the resulting statement was empty (or only had comments)
    if (rawStatement == null)
    {
      throw new SQLiteException("No SQL statement to prepare", SQLiteResultCode.MISUSE);
    }

    // Reject anything after the statement other than whitespace, comments and semicolons.
    var offset = tailOffset(start, tail, 0);
    while (offset < length)
    {
      var restStatement:RawPointer<RawSQLiteStatement> = null;
      result = sqlite3_prepare_v2(db.raw, cast start.add(offset).raw, length - offset, RawPointer.addressOf(restStatement), RawPointer.addressOf(tail));
      if (result != SQLiteResultCode.OK || restStatement != null)
      {
        // The rest can fail to compile on its own, for example when it uses a table the first statement creates.
        var error:Null<String> = result != SQLiteResultCode.OK ? sqlite3_errmsg(db.raw) : null;
        sqlite3_finalize(restStatement);
        sqlite3_finalize(rawStatement);
        var message = 'Only one statement can be prepared at a time, but found more: "${utf8.getString(offset, length - offset)}"';
        if (error != null) message += ' ($error)';
        message += '. Use exec() to run several statements without parameters.';
        throw new SQLiteException(message, SQLiteResultCode.MISUSE);
      }

      var nextOffset = tailOffset(start, tail, offset);
      // SQLite stops reading at a NUL character, so it consumes nothing when the rest starts with one.
      if (nextOffset == offset)
      {
        sqlite3_finalize(rawStatement);
        throw new SQLiteException("SQL must not contain a NUL character", SQLiteResultCode.MISUSE);
      }
      offset = nextOffset;
    }

    var stmt = new SQLiteStatement(this, Pointer.fromRaw(rawStatement));

    // Prune
    if (statements.length >= pruneLength)
    {
      statements = statements.filter(ref -> ref.get() != null);
      pruneLength = Std.int(Math.max(MIN_PRUNE_LENGTH, statements.length * 2));
    }

    statements.push(new WeakRef(stmt));
    return stmt;
  }

  /**
   * Runs a script of one or more SQL statements in order, such as pragmas or schema creation.
   * 
   * The script CANNOT have bound parameters, and rows returned by its statements are discarded.
   * Use `prepare()` to run a single statement that needs parameters or returns rows.
   *
   * If a statement fails, the script stops there.
   * The statements before it stay applied unless they are in a transaction that gets rolled back (see `SQLiteExecOptions.rollbackOnError`).
   *
   * @param sql The statements, separated by semicolons.
   * @param options See `SQLiteExecOptions`.
   * @throws SQLiteException `MISUSE` if the database is closed, or if `sql` is invalid (empty, only whitespace, contains a NUL character).
   *   Otherwise the error SQLite reports for the statement that failed.
   */
  public function exec(sql:String, ?options:SQLiteExecOptions):Void
  {
    checkOpen();
    if (StringTools.trim(sql) == "") throw new SQLiteException("No SQL statement to execute", SQLiteResultCode.MISUSE);

    // `sqlite3_exec` reads up to a NUL, so a NUL inside the SQL would silently drop the rest of the script.
    var utf8 = Bytes.ofString(sql);
    var length = utf8.length;
    for (i in 0...length)
    {
      if (utf8.get(i) == 0) throw new SQLiteException("SQL must not contain a NUL character", SQLiteResultCode.MISUSE);
    }
    var terminated = Bytes.alloc(length + 1);
    terminated.blit(0, utf8, 0, length);
    terminated.set(length, 0);
    var start:Pointer<Char> = NativeArray.address(terminated.getData(), 0).reinterpret();

    var wasInTransaction = inTransaction();
    var result:SQLiteResultCode = sqlite3_exec(db.raw, cast start.raw, null, null, null);
    if (result != SQLiteResultCode.OK)
    {
      // Read the error first, since the rollback replaces it.
      var error = SQLiteException.fromConnection(db.raw);
      // Roll back a transaction the script started but didn't finish. A transaction the caller started is left alone.
      if ((options?.rollbackOnError ?? true) && !wasInTransaction) rollbackIfOpen();
      throw error;
    }
  }

  /**
   * Starts a transaction.
   * @see `commit()` or `rollback()` to end a transaction.
   * @see `transaction(fn)` for a callback that begins and commits a transaction for you.
   *
   * @param options See `SQLiteTransactionOptions`.
   * @throws SQLiteException `MISUSE` if the database is closed, `ERROR` if a transaction is already open,
   *   or `BUSY` if an `IMMEDIATE` or `EXCLUSIVE` transaction can't get its lock.
   */
  public function begin(?options:SQLiteTransactionOptions):Void
  {
    var mode = options?.mode ?? SQLiteTransactionMode.DEFERRED;
    exec('BEGIN $mode');
  }

  /**
   * Commits the open transaction.
   *
   * @throws SQLiteException `MISUSE` if the database is closed, `ERROR` if no transaction is open,
   *   or the error that stopped the commit. A failed commit keeps the transaction open.
   */
  public function commit():Void
  {
    exec("COMMIT");
  }

  /**
   * Rolls back the open transaction, undoing every change made in it.
   *
   * @throws SQLiteException `MISUSE` if the database is closed, or `ERROR` if no transaction is open.
   */
  public function rollback():Void
  {
    exec("ROLLBACK");
  }

  /**
   * Runs `fn` in a transaction.
   * Begins a transaction, then commits if it returns, and rolls back if it throws.
   *
   * Transaction calls can be nested safely thanks to savepoints!
   *
   * @param fn The work to do in the transaction.
   * @param options See `SQLiteTransactionOptions`. Ignored on nested transactions.
   * @return The value `fn` returns.
   * @throws Whatever `fn` throws, after the transaction is rolled back.
   *   `SQLiteException` with `MISUSE` if the database is closed or `fn` ended the transaction,
   *   or the error from starting or committing the transaction. A failed commit is rolled back.
   */
  public function transaction<T>(fn:() -> T,
    ?options:SQLiteTransactionOptions):T
  {
    checkOpen();
    if (inTransaction()) return savepoint(fn);

    begin(options);
    var result:T;
    try
    {
      result = fn();
    }
    catch (e:Exception)
    {
      rollbackIfOpen();
      throw e;
    }

    if (!inTransaction())
    {
      throw new SQLiteException("The transaction was ended inside transaction()", SQLiteResultCode.MISUSE);
    }
    try
    {
      commit();
    }
    catch (e:SQLiteException)
    {
      rollbackIfOpen();
      throw e;
    }
    return result;
  }

  /**
   * Runs `fn` inside a savepoint.
   */
  private function savepoint<T>(fn:() -> T):T
  {
    // We reuse the same static name because `RELEASE` and `ROLLBACK TO` operate on the last savepoint with that name.
    exec('SAVEPOINT $SAVEPOINT_NAME');
    var result:T;
    try
    {
      result = fn();
    }
    catch (e:Exception)
    {
      // If SQLite rolled back the whole transaction after the error, the savepoint is already gone.
      if (inTransaction())
      {
        sqlite3_exec(db.raw, 'ROLLBACK TO $SAVEPOINT_NAME; RELEASE $SAVEPOINT_NAME', null, null, null);
      }
      throw e;
    }
    // Releasing a nested savepoint keeps its changes in the outer transaction.
    exec('RELEASE $SAVEPOINT_NAME');
    return result;
  }

  private static inline final SAVEPOINT_NAME:String = "libsqlite3_transaction";

  /**
   * Rolls back the open transaction, if there is one, after an error.
   * Some errors (such as `FULL`, `IOERR`, or a conflict with `OR ROLLBACK`) make SQLite roll back by itself,
   * and `ROLLBACK` with no transaction open would fail.
   * The result is ignored, because the error that caused the rollback is the one to report.
   */
  private function rollbackIfOpen():Void
  {
    if (inTransaction()) sqlite3_exec(db.raw, "ROLLBACK", null, null, null);
  }

  /**
   * @return How many bytes `tail` is past `start`.
   * We know the value is at least `fromOffset`.
   */
  private static extern inline function tailOffset(start:Pointer<Char>, tail:ConstCharStar, fromOffset:Int):Int
  {
    var offset = fromOffset;
    while ((cast start.add(offset).raw : ConstCharStar) != tail)
    {
      offset++;
    }
    return offset;
  }

  // Called by `SQLiteStatement.close()` once the statement is finalized.

  private function onStatementClosed(stmt:SQLiteStatement):Void
  {
    // Remove the closed statement from `statements`
    for (i in 0...statements.length)
    {
      if (statements[i].get() == stmt)
      {
        statements.splice(i, 1);
        return;
      }
    }
  }

  public function lastInsertRowId():Int64
  {
    checkOpen();
    return sqlite3_last_insert_rowid(db.raw);
  }

  public function changes():Int64
  {
    checkOpen();

    return sqlite3_changes64(db.raw);
  }

  /**
   * @return The number of rows changed by every `INSERT`, `UPDATE` and `DELETE` since the connection opened,
   *   where `changes()` counts only the most recent statement.
   * @throws SQLiteException `MISUSE` if the database is closed.
   */
  public function totalChanges():Int64
  {
    checkOpen();
    return sqlite3_total_changes64(db.raw);
  }

  /**
   * @return Whether a transaction is open, from `begin()`, `transaction()` or a `BEGIN` statement.
   * @throws SQLiteException `MISUSE` if the database is closed.
   */
  public function inTransaction():Bool
  {
    checkOpen();
    // SQLite is in autocommit mode whenever no transaction is open.
    return sqlite3_get_autocommit(db.raw) == 0;
  }

  /**
   * @return The absolute path of the main database file,
   *   or an empty string for an in-memory database (`":memory:"` or `SQLite.openFromBytes()`).
   * @throws SQLiteException `MISUSE` if the database is closed.
   */
  public function filename():String
  {
    checkOpen();
    var name:Null<String> = sqlite3_db_filename(db.raw, "main");
    // SQLite may return either NULL or "" for an in-memory database.
    return name ?? "";
  }

  /**
   * @return Whether the main database is read-only, from `SQLiteOpenOptions.readOnly`.
   * @throws SQLiteException `MISUSE` if the database is closed.
   */
  public function isReadOnly():Bool
  {
    checkOpen();
    var result = sqlite3_db_readonly(db.raw, "main");
    // -1 means there is no database by that name, which can't happen for "main".
    if (result < 0) throw new SQLiteException("The main database is missing", SQLiteResultCode.INTERNAL);
    // SQLite reports a database loaded with `SQLITE_DESERIALIZE_READONLY` as writable, so check that separately.
    return result == 1 || deserializedReadOnly;
  }

  /**
   * Whether `deserialize` loaded the main database read-only.
   */
  private var deserializedReadOnly:Bool = false;

  /**
   * Exports the main database into `Bytes`, in the SQLite file format.
   * Works for file and in-memory databases.
   * You can use `SQLite.openFromBytes` to load the result later.
   * 
   * @return The database content.
   * @throws SQLiteException `MISUSE` if the database is closed, or the error SQLite reports.
   */
  public function toBytes():Bytes
  {
    checkOpen();

    var rawSize:cpp.Int64 = 0;
    var data:RawPointer<UInt8> = sqlite3_serialize(db.raw, "main", RawPointer.addressOf(rawSize), 0);
    var size:Int64 = rawSize;
    if (data == null)
    {
      // An empty in-memory database has size 0, and SQLite can't allocate 0 bytes.
      if (size == 0) return Bytes.alloc(0);
      // SQLite ran out of memory trying to serialize.
      if (size > 0) throw new SQLiteException("Out of memory serializing the database", SQLiteResultCode.NOMEM);
      // SQLite couldn't read the database, such as when it isn't one.
      throw SQLiteException.fromConnection(db.raw);
    }

    if (size > 0x7FFFFFFF)
    {
      // 2,147,483,647 bytes (~2GB)
      // The database was too large to export as a single Bytes object.
      // In a basic database I calculated this as being something like 10 million rows which should be FINE.
      sqlite3_free(cast data);
      throw new SQLiteException('Database is too large for Bytes (${size} bytes)', SQLiteResultCode.TOOBIG);
    }

    var length:Int = Int64.toInt(size);
    var bytes = Bytes.alloc(length);
    if (length > 0)
    {
      var dest:Pointer<cpp.Void> = NativeArray.address(bytes.getData(), 0).reinterpret();
      Stdlib.nativeMemcpy(dest.raw, cast data, length);
    }
    sqlite3_free(cast data);
    return bytes;
  }

  /**
   * Replaces this database with the contents of the provided `Bytes.`
   * @param bytes Must be a serialized SQLite database, such as the contents of a DB file or the result of `serialize()`.
   */
  @:allow(sqlite.SQLite)
  private function deserialize(bytes:Bytes, readOnly:Bool):Void
  {
    checkOpen();

    var length = bytes.length;
    // Add some padding to prevent errors with malformed datbases.
    var bufferSize = length + DESERIALIZE_PADDING;
    var rawBuffer:RawPointer<cpp.Void> = sqlite3_malloc64(bufferSize);
    if (rawBuffer == null) throw new SQLiteException("Out of memory loading the database", SQLiteResultCode.NOMEM);
    var buffer:Pointer<UInt8> = Pointer.fromRaw(rawBuffer).reinterpret();
    if (length > 0)
    {
      var source:Pointer<cpp.Void> = NativeArray.address(bytes.getData(), 0).reinterpret();
      Stdlib.nativeMemcpy(cast buffer.raw, cast source.raw, length);
    }
    for (i in length...bufferSize)
    {
      buffer.setAt(i, 0);
    }

    // FREEONCLOSE ensures SQLite owns the buffer from here on, and frees it even if deserializing fails.
    var flags = SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE;
    if (readOnly) flags |= SQLITE_DESERIALIZE_READONLY;
    var result:SQLiteResultCode = sqlite3_deserialize(db.raw, "main", buffer.raw, length, bufferSize, flags);
    if (result != SQLiteResultCode.OK)
    {
      var error = SQLiteException.fromConnection(db.raw);
      // Some failures, such as running out of memory, don't record an error on the connection.
      if (error.code != result) error = new SQLiteException(sqlite3_errstr(result), result);
      throw error;
    }
    deserializedReadOnly = readOnly;
  }

  /**
   * Spare bytes after the content of a deserialized database, as `sqlite3_deserialize` recommends.
   */
  private static inline final DESERIALIZE_PADDING:Int = 20;

  private function checkOpen():Void
  {
    if (db == null) throw new SQLiteException("Database is closed", SQLiteResultCode.MISUSE);
  }
}

/**
 * Options for `SQLiteDatabase.exec()`.
 */
typedef SQLiteExecOptions =
{
  /**
   * If `true` and a statement fails while a transaction the script started is still open
   * (such as between its `BEGIN` and `COMMIT`), that transaction is rolled back.
   * A transaction that was already open when `exec()` was called is never rolled back.
   * If `false`, the transaction stays open, and the caller must `COMMIT` or `ROLLBACK` it.
   *
   * @default `true`
   */
  var ?rollbackOnError:Bool;
}

/**
 * Options for `SQLiteDatabase.begin()` and `SQLiteDatabase.transaction()`.
 */
typedef SQLiteTransactionOptions =
{
  /**
   * How the transaction takes its locks. See `SQLiteTransactionMode`.
   *
   * @default `DEFERRED`
   */
  var ?mode:SQLiteTransactionMode;
}
#end
