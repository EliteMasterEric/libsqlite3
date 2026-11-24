package regression;

import cpp.vm.Gc;
import haxe.Exception;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sys.FileSystem;
import utest.Assert;
import utest.Test;

/**
 * A database dropped without `close()` must release its connection, and any locks it holds, once it is
 * garbage collected.
 *
 * The check is whether a second connection can write: an exclusive lock held by a leaked connection makes
 * every write from another connection fail with "database is locked".
 *
 * Each test uses its own file, because on Windows a leaked connection also stops its file from being deleted.
 */
class TestUnclosedDatabase extends Test {
	// Control: shows the write check detects a held lock, and sees it released by an explicit close.
	function testLockReleasedByClose() {
		var path = createDatabase("unclosed-control.db");
		var holder = lockDatabase(path);
		Assert.isFalse(canWrite(path));
		holder.close();
		Assert.isTrue(canWrite(path));
		deleteDatabase(path);
	}

	function testLockReleasedByGarbageCollection() {
		var path = createDatabase("unclosed-gc.db");
		lockAndDrop(path);
		// Proves the dropped connection still holds the lock. This call also overwrites any stale copy of the
		// connection pointer left on the stack, which hxcpp's conservative stack scan would treat as a reference.
		Assert.isFalse(canWrite(path));
		// Two major collections, so objects freed by the first collection's finalizers are also collected.
		Gc.run(true);
		Gc.run(true);
		Assert.isTrue(canWrite(path));
		deleteDatabase(path);
	}

	static function createDatabase(path:String):String {
		deleteDatabase(path);
		var db = SQLite.open(path);
		db.prepare("CREATE TABLE t (x INTEGER)").executeStatement();
		db.close();
		return path;
	}

	static function lockDatabase(path:String):SQLiteDatabase {
		var db = SQLite.open(path);
		db.prepare("BEGIN EXCLUSIVE").executeStatement();
		return db;
	}

	// A separate function, so no reference to the database stays in the calling test's stack frame.
	static function lockAndDrop(path:String):Void {
		lockDatabase(path);
	}

	static function canWrite(path:String):Bool {
		var db = SQLite.open(path);
		try {
			db.prepare("INSERT INTO t (x) VALUES (1)").executeStatement();
			db.close();
			return true;
		} catch (e:Exception) {
			db.close();
			return false;
		}
	}

	static function deleteDatabase(path:String):Void {
		for (file in [path, path + "-journal"]) {
			if (FileSystem.exists(file)) FileSystem.deleteFile(file);
		}
	}
}
