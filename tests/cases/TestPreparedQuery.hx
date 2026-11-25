package cases;

import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import cases.util.DBCreator;
import utest.Test;

class TestPreparedQuery extends Test
{
  function setupClass()
  {
    DBCreator.create();
  }

  function testBasicSelectWhere()
  {
    var db = SQLite.open("persons.db");
    var stmt = db.prepare("SELECT * FROM Person WHERE personId = ?");
    stmt.bindInt(1, 1);
    var rs = RecordUtils.toArray(stmt.executeQuery());

    Assert.equals(1, rs.length);

    Assert.equals(1, rs[0].personId);
    Assert.equals("Ian", rs[0].firstName);
    Assert.equals("Harrigan", rs[0].lastName);
    Assert.equals(1, rs[0].iconId);

    db.close();
  }

  function testBasicSelectWhereOr()
  {
    var db = SQLite.open("persons.db");
    var stmt = db.prepare("SELECT * FROM Person WHERE personId = ? OR personId = ?");
    stmt.bindInt(1, 1);
    stmt.bindInt(2, 4);
    var rs = RecordUtils.toArray(stmt.executeQuery());

    Assert.equals(2, rs.length);

    Assert.equals(1, rs[0].personId);
    Assert.equals("Ian", rs[0].firstName);
    Assert.equals("Harrigan", rs[0].lastName);
    Assert.equals(1, rs[0].iconId);

    Assert.equals(4, rs[1].personId);
    Assert.equals("Jim", rs[1].firstName);
    Assert.equals("Parker", rs[1].lastName);
    Assert.equals(1, rs[1].iconId);

    db.close();
  }

  function testBasicSelectWhereAnd()
  {
    var db = SQLite.open("persons.db");
    var stmt = db.prepare("SELECT * FROM Person WHERE personId = ? AND firstName = ?");
    stmt.bindInt(1, 1);
    stmt.bindString(2, "Ian");
    var rs = RecordUtils.toArray(stmt.executeQuery());

    Assert.equals(1, rs.length);

    Assert.equals(1, rs[0].personId);
    Assert.equals("Ian", rs[0].firstName);
    Assert.equals("Harrigan", rs[0].lastName);
    Assert.equals(1, rs[0].iconId);

    db.close();
  }
}
