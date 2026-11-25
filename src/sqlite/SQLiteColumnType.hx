package sqlite;

/**
 * The storage class of a result column value. `sqlite3_column_type` returns these.
 */
enum abstract SQLiteColumnType(Int) from Int to Int
{
  var INTEGER = 1;
  var FLOAT = 2;
  var TEXT = 3;
  var BLOB = 4;
  var NULL = 5;
}
