package regression;

import haxe.Int64;
import haxe.io.Bytes;
import sqlite.SQLite;
import sqlite.SQLiteException;
import utest.Assert;
import utest.Test;

/**
 * `bindJson` must not silently write a value that `haxe.Json.stringify` can't represent.
 * The writer turns classes it doesn't know into objects of their fields.
 * Either a faithful encoding or an `SQLiteException` is acceptable.
 */
class TestJsonLossyValues extends Test
{
  // haxe.Json.stringify of an Int64 crashes the process on hxcpp (access violation), which would stop the whole suite.
  @:ignore("haxe.Json.stringify crashes on an Int64 on hxcpp; enable once bindJson rejects or encodes Int64")
  function testInt64()
  {
    var json = bindJsonText({
      n: Int64.make(1, 0)
    });
    if (json != null)
    {
      Assert.equals('{"n":4294967296}', json);
    }
    else
    {
      Assert.pass();
    }
  }

  @:ignore("bindJson writes Bytes as an object of their fields; enable once bindJson rejects Bytes")
  function testBytes()
  {
    // JSON has no binary type, so there is no faithful encoding.
    var json = bindJsonText({
      b: Bytes.ofString("ab")
    });
    Assert.isNull(json, 'Bytes were bound as $json');
  }

  /**
   * @return The bound JSON text, or `null` if `bindJson` threw.
   */
  static function bindJsonText(value:Any):Null<String>
  {
    var db = SQLite.open(":memory:");
    try
    {
      var text:String = db.prepare("SELECT ? AS json").bindJson(1, value).executeQuery().next().json;
      db.close();
      return text;
    }
    catch (e:SQLiteException)
    {
      db.close();
      return null;
    }
  }
}
