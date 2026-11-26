package cases;

import haxe.Int64;
import haxe.PosInfos;
import haxe.io.Bytes;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteResultCode;
import utest.Assert;
import utest.Test;

/**
 * The wrapper's own checks before a bind: index range, and binding after an execution without `reset()`.
 */
class TestBindChecks extends Test
{
  var db:SQLiteDatabase;

  function setup()
  {
    db = SQLite.open(":memory:");
  }

  function teardown()
  {
    db.close();
  }

  function testIndexOutOfRangeThrowsRange()
  {
    var stmt = db.prepare("SELECT ?, ?");
    for (index in [0, -1, 3])
    {
      var error = catchError(() -> stmt.bindInt(index, 1));
      Assert.equals(SQLiteResultCode.RANGE, error?.code);
      Assert.isTrue(error?.message.indexOf('index $index is out of range') != -1, error?.message);
    }
  }

  function testEveryIndexBindChecksRange()
  {
    var stmt = db.prepare("SELECT ?");
    var binds:Array<() -> Void> = [
      () -> stmt.bindInt(2, 1),
      () -> stmt.bindInt64(2, Int64.ofInt(1)),
      () -> stmt.bindFloat(2, 1.5),
      () -> stmt.bindString(2, "a"),
      () -> stmt.bindString(2, null),
      () -> stmt.bindBytes(2, Bytes.ofString("a")),
      () -> stmt.bindNull(2),
      () -> stmt.bindBool(2, true),
      () -> stmt.bind(2, 1),
      () -> stmt.bindJson(2, {
      }),
    ];
    for (bind in binds)
    {
      Assert.equals(SQLiteResultCode.RANGE, catchError(bind)?.code);
    }
  }

  function testNoParametersMessage()
  {
    var error = catchError(() -> db.prepare("SELECT 1").bindInt(1, 1));
    Assert.equals(SQLiteResultCode.RANGE, error?.code);
    Assert.isTrue(error?.message.indexOf("has 0 parameters") != -1, error?.message);
  }

  function testBindAfterExecuteStatementThrowsMisuse()
  {
    db.exec("CREATE TABLE t (x INTEGER)");
    var insert = db.prepare("INSERT INTO t (x) VALUES (?)").bindInt(1, 1);
    insert.executeStatement();
    var error = catchError(() -> insert.bindInt(1, 2));
    Assert.equals(SQLiteResultCode.MISUSE, error?.code);
    Assert.isTrue(error?.message.indexOf("reset()") != -1, error?.message);
  }

  function testBindDuringIterationThrowsMisuse()
  {
    var query = db.prepare("SELECT value FROM json_each('[1,2,3]') WHERE value >= ?").bindInt(1, 1);
    var rows = query.executeQuery();
    rows.next();
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> query.bindInt(1, 2))?.code);
  }

  function testBindAfterExecutionByNameAndBulkThrowsMisuse()
  {
    var query = db.prepare("SELECT :a AS a").bindIntByName(":a", 1);
    query.executeQuery().next();
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> query.bindIntByName(":a", 2))?.code);
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> query.bindAll([2]))?.code);
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> query.bindAllByName([":a" => 2]))?.code);
    Assert.equals(SQLiteResultCode.MISUSE, catchError(() -> query.bindObject({
      a: 2
    }))?.code);
  }

  function testBindAfterResetWorks()
  {
    var query = db.prepare("SELECT ? AS v").bindInt(1, 1);
    Assert.equals(1, query.executeQuery().next().v);
    query.reset().bindInt(1, 2);
    Assert.equals(2, query.executeQuery().next().v);
  }

  function testBindAfterStepErrorAndResetWorks()
  {
    db.exec("CREATE TABLE t (x INTEGER NOT NULL)");
    var insert = db.prepare("INSERT INTO t (x) VALUES (?)").bindNull(1);
    Assert.equals(SQLiteResultCode.CONSTRAINT, catchError(() -> insert.executeStatement())?.code);
    insert.reset().bindInt(1, 5).executeStatement();
    Assert.equals(5, db.prepare("SELECT x FROM t").executeQuery().next().x);
  }

  static function catchError(action:() -> Void, ?pos:PosInfos):Null<SQLiteException>
  {
    try
    {
      action();
    }
    catch (e:SQLiteException)
    {
      return e;
    }
    Assert.fail("Expected an SQLiteException", pos);
    return null;
  }
}
