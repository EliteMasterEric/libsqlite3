package regression;

import cpp.vm.Gc;
import haxe.Exception;
import sqlite.SQLite;
import sqlite.SQLiteDatabase;
import sys.FileSystem;
import sys.thread.Lock;
import sys.thread.Thread;
import utest.Assert;
import utest.Test;

/**
 * A database or statement dropped without `close()` must release its handle, and any locks it holds, once it is
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
		runInThread(() -> lockDatabase(path));
		// Proves the dropped connection still holds the lock.
		Assert.isFalse(canWrite(path));
		Assert.isTrue(collectUntilWritable(path));
		deleteDatabase(path);
	}

	// An unfinished query holds a read lock until its statement is finalized, which blocks other connections from
	// committing. Dropping it relies on the statement's finalizer.
	function testReadLockReleasedByGarbageCollection() {
		var path = createDatabase("unclosed-read.db");
		runInThread(() -> {
			var db = SQLite.open(path);
			db.prepare("INSERT INTO t (x) VALUES (1), (2), (3)").executeStatement();
			db.prepare("SELECT x FROM t").executeQuery().next();
		});
		Assert.isFalse(canWrite(path));
		Assert.isTrue(collectUntilWritable(path));
		deleteDatabase(path);
	}

	// Collecting a database and statements that were already closed must not close them a second time.
	function testClosedObjectsCollectedSafely() {
		runInThread(() -> {
			var db = SQLite.open(":memory:");
			var stmt = db.prepare("SELECT 1");
			stmt.executeQuery();
			stmt.close();
			db.prepare("SELECT 2");
			db.close();
		});
		Gc.run(true);
		Gc.run(true);
		Assert.pass();
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

	/**
	 * Runs `action` on a worker thread, so the objects it creates and drops are referenced from no live stack.
	 * hxcpp scans every registered thread's stack conservatively, so a stale copy of a pointer on a live stack
	 * would keep its object alive. Once the worker exits its stack is no longer scanned, and the main thread
	 * never held a reference.
	 */
	static function runInThread(action:() -> Void):Void {
		var done = new Lock();
		var error:Null<Exception> = null;
		Thread.create(() -> {
			try {
				action();
			} catch (e:Exception) {
				error = e;
			}
			done.release();
		});
		done.wait();
		if (error != null) throw error;
	}

	/**
	 * Runs major collections until another connection can write, for up to about 5 seconds. Retrying covers
	 * the short time between the worker signalling and the worker thread being unregistered.
	 */
	static function collectUntilWritable(path:String):Bool {
		for (_ in 0...500) {
			// Two major collections, so objects freed by the first collection's finalizers are also collected.
			Gc.run(true);
			Gc.run(true);
			if (canWrite(path)) return true;
			Sys.sleep(0.01);
		}
		return false;
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
