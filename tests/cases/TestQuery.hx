package cases;

import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import cases.util.DBCreator;
import utest.Test;

class TestQuery extends Test
{
  function setupClass()
  {
    DBCreator.create();
  }

  function testBasicSelect()
  {
    var db = SQLite.open("persons.db");
    var stmt = db.prepare("SELECT * FROM Person");
    var rs = RecordUtils.toArray(stmt.executeQuery());

    Assert.equals(4, rs.length);

    Assert.equals(1, rs[0].personId);
    Assert.equals("Ian", rs[0].firstName);
    Assert.equals("Harrigan", rs[0].lastName);
    Assert.equals(1, rs[0].iconId);

    Assert.equals(3, rs[2].personId);
    Assert.equals("Tim", rs[2].firstName);
    Assert.equals("Mallot", rs[2].lastName);
    Assert.equals(2, rs[2].iconId);

    db.close();
  }

  function testBasicSelectWhere()
  {
    var db = SQLite.open("persons.db");
    var stmt = db.prepare("SELECT * FROM Person WHERE personId = 1");
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
    var stmt = db.prepare("SELECT * FROM Person WHERE personId = 1 OR personId = 4");
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
    var stmt = db.prepare("SELECT * FROM Person WHERE personId = 1 AND firstName = 'Ian'");
    var rs = RecordUtils.toArray(stmt.executeQuery());

    Assert.equals(1, rs.length);

    Assert.equals(1, rs[0].personId);
    Assert.equals("Ian", rs[0].firstName);
    Assert.equals("Harrigan", rs[0].lastName);
    Assert.equals(1, rs[0].iconId);

    db.close();
  }
}
