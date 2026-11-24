package sqlite;

/**
 * The storage class of a result column value, as returned by `sqlite3_column_type`.
 */
enum abstract SQLiteColumnType(Int) from Int to Int {
	var INTEGER = 1;
	var FLOAT = 2;
	var TEXT = 3;
	var BLOB = 4;
	var NULL = 5;
}
