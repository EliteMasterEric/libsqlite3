package cases;

import haxe.io.Bytes;
import cases.util.RecordUtils;
import sqlite.SQLite;
import utest.Assert;
import utest.Test;
import cases.util.DBCreator;

class TestBlob extends Test
{
  function setupClass()
  {
    DBCreator.create();
  }

  function testBasicBlob()
  {
    var db = SQLite.open("persons.db");
    var stmt = db.prepare("SELECT * FROM Person WHERE personId = 1");
    var rs = RecordUtils.toArray(stmt.executeQuery());

    Assert.equals(1, rs.length);

    Assert.equals(1, rs[0].personId);
    Assert.equals("Ian", rs[0].firstName);
    Assert.equals("Harrigan", rs[0].lastName);
    Assert.equals(1, rs[0].iconId);
    Assert.isOfType(rs[0].contractDocument, Bytes);
    Assert.equals(Bytes.ofString("this is ians contract document").toString(), rs[0].contractDocument.toString());
  }

  function testBasicBlobInsert()
  {
    var db = SQLite.open("persons.db");

    var stmt = db.prepare(
      "INSERT INTO Person (lastName, firstName, iconId, contractDocument) VALUES ('new last name', 'new first name', 1, X'746869732069732061206e657720636f6e747261637420646f63756d656e74')"
    );
    stmt.executeQuery();

    var lastInsertedId = haxe.Int64.toInt(db.lastInsertRowId());
    Assert.equals(5, lastInsertedId);

    var stmt = db.prepare("SELECT * FROM Person WHERE personId = " + lastInsertedId);
    var rs = RecordUtils.toArray(stmt.executeQuery());

    Assert.equals(1, rs.length);

    Assert.equals(5, rs[0].personId);
    Assert.equals("new first name", rs[0].firstName);
    Assert.equals("new last name", rs[0].lastName);
    Assert.equals(1, rs[0].iconId);
    Assert.isOfType(rs[0].contractDocument, Bytes);
    Assert.equals(Bytes.ofString("this is a new contract document").toString(), rs[0].contractDocument.toString());

    db.close();
  }
}
