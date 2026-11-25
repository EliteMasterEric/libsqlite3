package cases;

import haxe.Int64;
import haxe.PosInfos;
import haxe.io.Bytes;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sqlite.SQLiteException;
import sqlite.SQLiteExtendedResultCode;
import sqlite.SQLiteResultCode;
import sys.FileSystem;
import sys.io.File;
import utest.Assert;
import utest.Test;

/**
 * `SQLiteDatabase.toBytes()` exports a database, and `SQLite.openFromBytes()` loads one into memory.
 */
class TestSerialize extends Test {
	static inline final FILE_PATH = "serialize-test.db";

	function testRoundTrip() {
		var source = createSample(":memory:");
		var bytes = source.toBytes();
		source.close();

		var db = SQLite.openFromBytes(bytes);
		assertSample(db);
		db.close();
	}

	// A file database exports the same bytes as the file, and both load.
	function testFileDatabase() {
		deleteFile();
		var source = createSample(FILE_PATH);
		var bytes = source.toBytes();
		source.close();

		var fileBytes = File.getBytes(FILE_PATH);
		Assert.equals(0, bytes.compare(fileBytes));

		var fromExport = SQLite.openFromBytes(bytes);
		assertSample(fromExport);
		fromExport.close();

		var fromFile = SQLite.openFromBytes(fileBytes);
		assertSample(fromFile);
		fromFile.close();
		deleteFile();
	}

	// Writes grow the database past its original size, without changing the bytes it was loaded from.
	function testWritesGrow() {
		var source = createSample(":memory:");
		var bytes = source.toBytes();
		source.close();
		var original = bytes.sub(0, bytes.length);

		var db = SQLite.openFromBytes(bytes);
		var large = Bytes.alloc(64 * 1024);
		large.fill(0, large.length, 0x42);
		db.prepare("INSERT INTO t (id, name, data) VALUES (2, 'large', ?)").bindBytes(1, large).executeStatement();

		var grown = db.toBytes();
		// The original is much smaller than the blob, so this proves it grew past its buffer.
		Assert.isTrue(bytes.length < large.length);
		Assert.isTrue(grown.length > large.length);
		Assert.equals(0, bytes.compare(original));

		var row:Dynamic = db.prepare("SELECT data FROM t WHERE id = 2").executeQuery().next();
		Assert.equals(0, large.compare(row.data));
		db.close();

		// The export holds the new row too.
		var reloaded = SQLite.openFromBytes(grown);
		var count:Dynamic = reloaded.prepare("SELECT count(*) AS n FROM t").executeQuery().next();
		Assert.equals(2, count.n);
		reloaded.close();
	}

	function testReadOnly() {
		var source = createSample(":memory:");
		var bytes = source.toBytes();
		source.close();

		var db = SQLite.openFromBytes(bytes, true);
		assertSample(db);
		var e = catchError(() -> db.prepare("INSERT INTO t (id) VALUES (2)").executeStatement());
		assertCodes(e, SQLiteResultCode.READONLY, SQLiteExtendedResultCode.READONLY);
		db.close();
	}

	// SQLite doesn't check the content when loading it, only when a statement first reads the schema.
	function testInvalidBytes() {
		var garbage = Bytes.alloc(4096);
		var seed = 12345;
		for (i in 0...garbage.length) {
			seed = seed * 1103515245 + 12345;
			garbage.set(i, (seed >> 16) & 0xFF);
		}

		var db = SQLite.openFromBytes(garbage);
		var e = catchError(() -> db.prepare("SELECT * FROM sqlite_master"));
		assertCodes(e, SQLiteResultCode.NOTADB, SQLiteExtendedResultCode.NOTADB);
		db.close();
	}

	// Empty bytes give an empty database, which exports as empty bytes until something is written.
	function testEmptyBytes() {
		var db = SQLite.openFromBytes(Bytes.alloc(0));
		Assert.equals(0, db.toBytes().length);

		db.prepare("CREATE TABLE t (v TEXT)").executeStatement();
		db.prepare("INSERT INTO t (v) VALUES ('x')").executeStatement();
		var row:Dynamic = db.prepare("SELECT v FROM t").executeQuery().next();
		Assert.equals("x", row.v);
		Assert.isTrue(db.toBytes().length > 0);
		db.close();
	}

	function testNullBytes() {
		var e = catchError(() -> SQLite.openFromBytes(null));
		assertCodes(e, SQLiteResultCode.MISUSE, SQLiteExtendedResultCode.MISUSE);
	}

	// The database holds its own copy, so changing the source afterwards does nothing.
	function testSourceCopied() {
		var source = createSample(":memory:");
		var bytes = source.toBytes();
		source.close();

		var db = SQLite.openFromBytes(bytes);
		bytes.fill(0, bytes.length, 0);
		assertSample(db);
		db.close();
	}

	function testToBytesAfterClose() {
		var db = SQLite.open(":memory:");
		db.close();
		var e = catchError(() -> db.toBytes());
		assertCodes(e, SQLiteResultCode.MISUSE, SQLiteExtendedResultCode.MISUSE);
	}

	static final SAMPLE_BIG:Int64 = Int64.make(0x12345678, 0x9abcdef0);

	static function sampleBlob():Bytes {
		var blob = Bytes.alloc(4);
		blob.set(0, 0);
		blob.set(1, 1);
		blob.set(2, 0xFE);
		blob.set(3, 0xFF);
		return blob;
	}

	/**
	 * Creates a table with one row holding TEXT, BLOB, a 64-bit INTEGER and NULL.
	 */
	static function createSample(path:String):SQLiteDatabase {
		var db = SQLite.open(path);
		db.prepare("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, data BLOB, big INTEGER, missing TEXT)").executeStatement();
		db.prepare("INSERT INTO t (id, name, data, big, missing) VALUES (1, ?, ?, ?, NULL)")
			.bindString(1, "héllo")
			.bindBytes(2, sampleBlob())
			.bindInt64(3, SAMPLE_BIG)
			.executeStatement();
		return db;
	}

	static function assertSample(db:SQLiteDatabase, ?pos:PosInfos):Void {
		var rows = db.prepare("SELECT * FROM t WHERE id = 1").executeQuery();
		Assert.isTrue(rows.hasNext(), pos);
		var row:Dynamic = rows.next();
		Assert.equals("héllo", row.name, pos);
		Assert.equals(0, sampleBlob().compare(row.data), pos);
		Assert.isTrue(SAMPLE_BIG == (row.big : Int64), pos);
		Assert.isTrue(Reflect.hasField(row, "missing"), pos);
		Assert.isNull(row.missing, pos);
	}

	static function catchError(action:() -> Void, ?pos:PosInfos):Null<SQLiteException> {
		try {
			action();
		} catch (e:SQLiteException) {
			return e;
		}
		Assert.fail("Expected an SQLiteException", pos);
		return null;
	}

	static function assertCodes(e:Null<SQLiteException>, code:SQLiteResultCode, extendedCode:SQLiteExtendedResultCode, ?pos:PosInfos):Void {
		if (e == null) return;
		Assert.equals(code, e.code, pos);
		Assert.equals(extendedCode, e.extendedCode, pos);
	}

	static function deleteFile():Void {
		for (file in [FILE_PATH, FILE_PATH + "-journal"]) {
			if (FileSystem.exists(file)) FileSystem.deleteFile(file);
		}
	}
}
