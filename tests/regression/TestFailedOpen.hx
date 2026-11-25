package regression;

import haxe.Exception;
import haxe.Int64;
import sqlite.SQLite;
import sqlite._internal.RawSQLite.sqlite3_memory_used;
import utest.Assert;
import utest.Test;

/**
 * A failed `SQLite.open` must throw and free the connection handle, which SQLite allocates even when the open
 * fails. A leaked handle shows up as memory that SQLite never gets back.
 */
class TestFailedOpen extends Test
{
  static inline final MISSING_PATH = "no-such-directory/test.db";
  static inline final ATTEMPTS = 20;

  function testFailedOpenThrows()
  {
    Assert.raises(() -> SQLite.open(MISSING_PATH), Exception);
  }

  function testFailedOpenFreesHandle()
  {
    // One attempt first, so one-time allocations (such as SQLite's own initialization) aren't counted.
    tryOpenMissing();

    var beforeBytes:Int64 = sqlite3_memory_used();
    for (i in 0...ATTEMPTS)
    {
      tryOpenMissing();
    }
    var afterBytes:Int64 = sqlite3_memory_used();
    var grownBytes = Int64.toInt(afterBytes - beforeBytes);

    // Each leaked connection holds several KB, so any real leak is far above this.
    Assert.isTrue(grownBytes < 1024, 'SQLite memory grew by $grownBytes bytes over $ATTEMPTS failed opens');
  }

  static function tryOpenMissing():Void
  {
    try
    {
      SQLite.open(MISSING_PATH);
    }
    catch (e:Exception)
    {
    }
  }
}
