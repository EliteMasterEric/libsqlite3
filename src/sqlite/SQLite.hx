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
  public static function open(path:String):SQLiteDatabase
  {
    var db:RawPointer<RawSQLite> = null;
    var result:SQLiteResultCode = sqlite3_open(path, RawPointer.addressOf(db));
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
   * @param readOnly If `true`, writes throw `READONLY`.
   * @return The open database.
   * @throws SQLiteException `MISUSE` if `bytes` is null, or the error SQLite reports.
   */
  public static function openFromBytes(bytes:Bytes, readOnly:Bool = false):SQLiteDatabase
  {
    if (bytes == null) throw new SQLiteException("Database bytes must not be null", SQLiteResultCode.MISUSE);

    var database = open(":memory:");
    try
    {
      database.deserialize(bytes, readOnly);
    }
    catch (e:SQLiteException)
    {
      database.close();
      throw e;
    }
    return database;
  }
}
#end
