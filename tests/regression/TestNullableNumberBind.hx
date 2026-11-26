package regression;

import haxe.Int64;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;

/**
 * Binding a null `Null<Int>`, `Null<Int64>` or `Null<Float>` with the typed binds must bind NULL, as `bindString` does.
 * On hxcpp the null becomes `0` when it is passed to a non-nullable parameter.
 */
class TestNullableNumberBind extends Test
{
  function testBindIntNull()
  {
    var db = SQLite.open(":memory:");
    var value:Null<Int> = null;
    var row = db.prepare("SELECT ? IS NULL AS boundNull").bindInt(1, value).executeQuery().next();
    Assert.equals(1, row.boundNull);
    db.close();
  }

  function testBindInt64Null()
  {
    var db = SQLite.open(":memory:");
    var value:Null<Int64> = null;
    var row = db.prepare("SELECT ? IS NULL AS boundNull").bindInt64(1, value).executeQuery().next();
    Assert.equals(1, row.boundNull);
    db.close();
  }

  function testBindFloatNull()
  {
    var db = SQLite.open(":memory:");
    var value:Null<Float> = null;
    var row = db.prepare("SELECT ? IS NULL AS boundNull").bindFloat(1, value).executeQuery().next();
    Assert.equals(1, row.boundNull);
    db.close();
  }

  function testBindByNameNull()
  {
    var db = SQLite.open(":memory:");
    var intValue:Null<Int> = null;
    var int64Value:Null<Int64> = null;
    var floatValue:Null<Float> = null;
    var boolValue:Null<Bool> = null;
    var row = db
      .prepare("SELECT :i IS NULL AS i, :l IS NULL AS l, :f IS NULL AS f, :b IS NULL AS b")
      .bindIntByName(":i", intValue)
      .bindInt64ByName(":l", int64Value)
      .bindFloatByName(":f", floatValue)
      .bindBoolByName(":b", boolValue)
      .executeQuery()
      .next();
    Assert.equals(1, row.i);
    Assert.equals(1, row.l);
    Assert.equals(1, row.f);
    Assert.equals(1, row.b);
    db.close();
  }

  function testNonNullValuesStillBind()
  {
    var db = SQLite.open(":memory:");
    var intValue:Null<Int> = 0;
    var floatValue:Null<Float> = 1.5;
    var boolValue:Null<Bool> = false;
    var row = db
      .prepare("SELECT ?1 AS i, typeof(?1) AS t, ?2 AS f, ?3 AS b")
      .bindInt(1, intValue)
      .bindFloat(2, floatValue)
      .bindBool(3, boolValue)
      .executeQuery()
      .next();
    Assert.equals(0, row.i);
    Assert.equals("integer", row.t);
    Assert.equals(1.5, row.f);
    Assert.equals(0, row.b);
    db.close();
  }

  function testBindBoolNull()
  {
    var db = SQLite.open(":memory:");
    var value:Null<Bool> = null;
    var row = db.prepare("SELECT ? IS NULL AS boundNull").bindBool(1, value).executeQuery().next();
    Assert.equals(1, row.boundNull);
    db.close();
  }
}
