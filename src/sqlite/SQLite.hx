package sqlite;

#if cpp
import cpp.Pointer;
import cpp.RawPointer;
import haxe.io.Bytes;
import sqlite._internal.RawSQLite;
import sqlite._internal.RawSQLite.*;

/**
 * Call `SQLite.open(path)` to get an SQLite Database object to perform queries on.
 */
@:unreflective
class SQLite
{
  /**
   * The version of the SQLite library compiled into this build, such as `"3.54.1"`.
   */
  public static var version(get, never):String;

  /**
   * The SQLite library version as one number: `major * 1000000 + minor * 1000 + patch`, such as `3054001`.
   */
  public static var versionNumber(get, never):Int;

  static function get_version():String
  {
    return sqlite3_libversion();
  }

  static function get_versionNumber():Int
  {
    return sqlite3_libversion_number();
  }

  /**
   * Opens the database file at `path`, creating it if it doesn't exist (see `createIfMissing`).
   *
   * @param path The database file.
   *   Use `":memory:"` for a new in-memory database.
   * @param options See `SQLiteOpenOptions`.
   * @return The open database.
   * @throws SQLiteException `MISUSE` if you try to create a new `readOnly` database.
   *   otherwise the error SQLite reports, such as `CANTOPEN` for a missing file.
   */
  public static function open(path:String, ?options:SQLiteOpenOptions):SQLiteDatabase
  {
    var readOnly = options?.readOnly ?? false;
    var createIfMissing = options?.createIfMissing ?? !readOnly;
    // SQLite doesn't allow READONLY together with CREATE.
    if (readOnly && createIfMissing)
    {
      throw new SQLiteException("A read-only database can't be created if missing", SQLiteResultCode.MISUSE);
    }

    var flags = readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE;
    if (createIfMissing) flags |= SQLITE_OPEN_CREATE;

    var db:RawPointer<RawSQLite> = null;
    var result:SQLiteResultCode = sqlite3_open_v2(path, RawPointer.addressOf(db), flags, null);
    if (result != SQLiteResultCode.OK)
    {
      // Read the error before closing, which frees it.
      var error = SQLiteException.fromConnection(db);

      // If SQLite fails to open the file, it still creates a handle.
      // That must be closed to prevent a leak.
      sqlite3_close_v2(db);

      throw error;
    }
    return new SQLiteDatabase(Pointer.fromRaw(db));
  }

  /**
   * Loads an in-memory database from the provided byte data.
   * Byte data should be the contents of an SQLite database file, or the output of `SQLiteDatabase.toBytes()`
   *
   * @param bytes The database content.
   * @param options See `SQLiteOpenOptions`.
   * @return The open database.
   * @throws SQLiteException `MISUSE` if `bytes` is null, or the error SQLite reports.
   */
  public static function openFromBytes(bytes:Bytes, ?options:SQLiteOpenOptions):SQLiteDatabase
  {
    if (bytes == null) throw new SQLiteException("Database bytes must not be null", SQLiteResultCode.MISUSE);

    // The connection itself stays writable; `deserialize` makes the loaded database read-only.
    var database = open(":memory:");
    try
    {
      database.deserialize(bytes, options?.readOnly ?? false);
    }
    catch (e:SQLiteException)
    {
      database.close();
      throw e;
    }
    return database;
  }
}

/**
 * Options for `SQLite.open()` and `SQLite.openFromBytes()`.
 */
typedef SQLiteOpenOptions =
{
  /**
   * If `true`, the database will be opened in read-only mode.
   * Attempted writes will throw an exception.
   * 
   * @default `false`
   */
  var ?readOnly:Bool;

  /**
   * If `true`, `SQLite.open()` creates the database file when it doesn't exist.
   * If `false`, a missing file throws `CANTOPEN`.
   * Can't be `true` together with `readOnly`. Ignored by `SQLite.openFromBytes()`.
   *
   * @default `true`, or `false` when `readOnly` is `true`
   */
  var ?createIfMissing:Bool;
}
#end
