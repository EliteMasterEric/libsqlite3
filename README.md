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

Parameters can also be named (`:name`, `@name` or `$name`) and bound by name, with the prefix included. A name used more than once is bound everywhere it appears.

```haxe
db.prepare("INSERT INTO Person (name, age) VALUES (:name, :age)")
	.bindStringByName(":name", "Bob")
	.bindIntByName(":age", 25)
	.executeStatement();
```

`bind()`, `bindByName()` and `bindAll()` pick the bind from the value's runtime type (`Int`, `haxe.Int64`, `Float`, `Bool` as `1`/`0`, `String`, `Bytes` or `null`). `bindAll()` takes one value for each parameter, in order, and throws `RANGE` if the count doesn't match.

```haxe
db.prepare("INSERT INTO Person (name, age) VALUES (?, ?)").bindAll(["Carol", 41]).executeStatement();
```

`bindAllByName()` does the same by name, and also needs one value for each parameter:

```haxe
db.prepare("INSERT INTO Person (name, age) VALUES (:name, :age)").bindAllByName([":name" => "Dan", ":age" => 52]).executeStatement();
```

`bindObject()` binds from the fields of an anonymous structure, matching each field to the parameter with that name and any prefix:

```haxe
var insert = db.prepare("INSERT INTO Person (name, age) VALUES (:name, :age)");
for (person in people) {
	insert.reset().bindObject(person).executeStatement(); // {name: "Eve", age: 33}
}
```

The bulk binds check every value before binding any, so an error leaves the earlier bindings in place. After a statement has been executed, call `reset()` before binding new values.

`bindJson()` and `bindJsonByName()` bind a value as JSON text, through `haxe.Json.stringify`, for use with SQLite's JSON functions. Bound text isn't marked as JSON, so wrap the parameter in `json()` when you pass it into another JSON function. For JSON text you already have, use `bindString()`, since `bindJson()` would encode it again as a string.

```haxe
db.prepare("INSERT INTO Event (data) VALUES (json_object('tags', json(?)))").bindJson(1, ["a", "b"]).executeStatement();
```

On hxcpp, a `Float` with a whole value (such as `2.0`) is an `Int` at runtime, so these bind it as an integer. Use `bindFloat()` when the storage class matters.

Column values map to Haxe types:

- `INTEGER`: `Int` (or `haxe.Int64` when the value does not fit)
- `REAL`: `Float`
- `TEXT`: `String`
- `BLOB`: `haxe.io.Bytes`
- `NULL`: `null`

Rows are keyed by column name, so `executeQuery()` throws `MISUSE` if two result columns share a name, such as `SELECT * FROM Person JOIN Icon` when both tables have an `iconId`. Give the columns distinct names with `AS`, or select only the columns you need.

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

### Connection info

```haxe
SQLite.version; // "3.54.1"
SQLite.versionNumber; // 3054001

db.filename(); // absolute path of the file, or "" for in-memory databases
db.isReadOnly(); // true when opened with {readOnly: true}
db.inTransaction(); // true between begin() and commit()/rollback(), and inside transaction()
db.changes(); // rows changed by the last statement
db.totalChanges(); // rows changed since the connection opened
```

Errors are thrown as `sqlite.SQLiteException`, which carries SQLite's result code.
