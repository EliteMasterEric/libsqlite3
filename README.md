<a href="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/windows.yaml"><img src="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/windows.yaml/badge.svg">
<a href="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/ubuntu.yaml"><img src="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/ubuntu.yaml/badge.svg">
<a href="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/mac.yaml"><img src="https://github.com/EliteMasterEric/libsqlite3/actions/workflows/mac.yaml/badge.svg">

# libsqlite3

A set of `sqlite3` externs for HXCPP.

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

Errors are thrown as `sqlite.SQLiteException`, which carries SQLite's result code.