<a href="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/windows.yaml"><img src="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/windows.yaml/badge.svg">
<a href="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/ubuntu.yaml"><img src="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/ubuntu.yaml/badge.svg">
<a href="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/mac.yaml"><img src="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/mac.yaml/badge.svg">

# libsqlite3

A set of `sqlite3` externs for HXCPP.

Originally based on code by [Stellation7](https://github.com/davidgiven/stellation/blob/stellation7/src/runtime/cpp/Sqlite.hx) and [Ian Harrigan](https://github.com/core-haxe/libsqlite3).

## Usage

Add `-lib libsqlite3` to your build. The library only supports the C++ (hxcpp) target.

```haxe
import sqlite.SQLite;

class Main {
	static function main() {
		var db = SQLite.open("example.db");

		db.prepare("CREATE TABLE IF NOT EXISTS Person (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)").executeStatement();

		// Bind values into prepared statements to avoid SQL injection.
		db.prepare("INSERT INTO Person (name, age) VALUES (?, ?)")
			.bindString(1, "Alice")
			.bindInt(2, 30)
			.executeStatement();
		trace('Inserted row ${haxe.Int64.toStr(db.lastInsertRowId())}');

		// executeQuery() returns an Iterator<Dynamic>
		var query = db.prepare("SELECT name, age FROM Person WHERE age >= ?").bindInt(1, 18);
		for (row in query.executeQuery()) {
			trace('${row.name} is ${row.age}');
		}

		db.close();
	}
}
```

Column values map to Haxe types:

- `INTEGER`: `Int` (or `haxe.Int64` when the value does not fit)
- `REAL`: `Float`
- `TEXT`: `String`
- `BLOB`: `haxe.io.Bytes`
- `NULL`: `null`

`prepare()` takes exactly one statement. To run a script of several statements with no parameters, such as pragmas or schema setup, use `exec()`. Rows that the script returns are discarded.

```haxe
db.exec("PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;");
db.exec("BEGIN; CREATE TABLE A (x INTEGER); CREATE TABLE B (y INTEGER); PRAGMA user_version = 1; COMMIT;");
```

If a statement fails, the script stops there, and `exec()` rolls back any transaction that the script opened and didn't finish. Pass `{rollbackOnError: false}` to leave that transaction open.

### Transactions

`transaction()` runs a function in a transaction. It commits when the function returns, and rolls back and rethrows when it throws. It returns the function's result.

```haxe
var eventId = db.transaction(() -> {
	db.prepare("INSERT INTO Event (name) VALUES (?)").bindString(1, "screenshot").executeStatement();
	db.prepare("UPDATE Session SET lastSeen = ?").bindInt(1, 1234).executeStatement();
	return db.lastInsertRowId();
}, {mode: SQLiteTransactionMode.IMMEDIATE}); // import sqlite.SQLiteTransactionMode
```

A `transaction()` call inside another one, or after `begin()`, uses a savepoint, so a failure undoes only its own work. For manual control, use `begin()`, `commit()` and `rollback()`.

### In-memory databases from bytes

`toBytes()` exports a database in the SQLite `.db` file format, and `SQLite.openFromBytes()` lets you load a database from memory, without having to touch the file system.

```haxe
var file = SQLite.open("example.db");
var bytes = file.toBytes(); // or sys.io.File.getBytes("example.db")
file.close();

var db = SQLite.openFromBytes(bytes); // writable, grows as needed
var readOnly = SQLite.openFromBytes(bytes, {readOnly: true}); // writes throw a READONLY exception
```

Empty bytes give an empty database. Bytes that aren't a database throw `NOTADB` on the first statement that reads them (not when the database is loaded).

Errors are thrown as `sqlite.SQLiteException`, which carries SQLite's result code.
