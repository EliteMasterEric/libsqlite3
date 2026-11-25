package regression;

import cpp.vm.Gc;
import haxe.Exception;
import haxe.Timer;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * For non-ASCII SQL, `prepare` passed SQLite a temporary UTF-8 copy and kept only pointers into the middle of it.
 * hxcpp's conservative stack scan doesn't keep an allocation alive through such pointers, so a collection
 * while `prepare` built its error message could free the copy before the rest of the SQL was read from it.
 *
 * No GC mode collects on every allocation, so this test makes collections frequent and repeats the failing
 * path many times. It can pass even while the bug is present.
 */
class TestPrepareTailGc extends Test
{
  static inline final DURATION_SECONDS:Float = 5;

  function testTrailingTextSurvivesCollection()
  {
    var db = SQLite.open(":memory:");

    // Long enough that the error message needs its own allocation of a useful size.
    var tail = " SELECT '" + StringTools.lpad("", "é", 200) + "'";
    var sql = "SELECT 'ü';" + tail;

    // Collect as soon as a little memory has been allocated.
    Gc.setMinimumWorkingMemory(0);
    Gc.setMinimumFreeSpace(0);
    Gc.setTargetFreeSpacePercentage(1);

    var iterations = 0;
    var failure:Null<String> = null;
    var endTime = Timer.stamp() + DURATION_SECONDS;
    while (failure == null && Timer.stamp() < endTime)
    {
      iterations++;
      try
      {
        db.prepare(sql).close();
        failure = "prepare did not throw";
      }
      catch (e:Exception)
      {
        if (e.message.indexOf(tail) < 0) failure = describeMismatch(e.message, tail);
      }
    }

    // The desktop defaults in hxcpp 4.3.2 (src/hx/gc/GcCommon.cpp).
    Gc.setMinimumWorkingMemory(20 * 1024 * 1024);
    Gc.setMinimumFreeSpace(10 * 1024 * 1024);
    Gc.setTargetFreeSpacePercentage(100);

    db.close();

    if (failure != null)
    {
      Assert.fail('Iteration $iterations: $failure');
    }
    else
    {
      Assert.pass('$iterations iterations');
    }
  }

  // A garbled message can contain characters that cut off the console output, so it is never printed.

  static function describeMismatch(message:String, tail:String):String
  {
    var start = message.indexOf('"') + 1;
    var i = 0;
    while (i < tail.length && message.charCodeAt(start + i) == tail.charCodeAt(i))
    {
      i++;
    }
    return 'trailing SQL in the message differs at character $i of ${tail.length}: code ${message.charCodeAt(start + i)}, expected ${tail.charCodeAt(i)}';
  }
}
