package cases.util;

import sqlite.SQLite;
import sys.io.File;

class DBCreator {
	public static function create(createDummyData:Bool = true):Void {
		File.saveContent("persons.db", "");
		createTables();

		if (createDummyData) {
			addDummyData();
		}
	}

	static function createTables():Void {
		var db = SQLite.open("persons.db");

		// One transaction for all tables to make tests faster.
		db.prepare("BEGIN;").executeStatement();

		var stmt = db.prepare("CREATE TABLE Person (
                personId INTEGER PRIMARY KEY AUTOINCREMENT,
                lastName varchar(50),
                firstName varchar(50),
                iconId int,
                contractDocument blob
            );");
		stmt.executeStatement();

		var stmt = db.prepare("CREATE TABLE Icon (
                iconId int,
                path varchar(50)
            );");
		stmt.executeStatement();

		var stmt = db.prepare("CREATE TABLE Organization (
                organizationId int,
                name varchar(50),
                iconId int
            );");
		stmt.executeStatement();

		var stmt = db.prepare("CREATE TABLE Person_Organization (
                Person_personId int,
                Organization_organizationId int
            );");
		stmt.executeStatement();

		db.prepare("COMMIT;").executeStatement();

		db.close();
	}

	public static function addDummyData():Void {
		var db = SQLite.open("persons.db");

		// One transaction for all inserts to make tests faster.
		db.prepare("BEGIN;").executeStatement();

		db.prepare("INSERT INTO Icon (iconId, path) VALUES (1, '/somepath/icon1.png');").executeStatement();
		db.prepare("INSERT INTO Icon (iconId, path) VALUES (2, '/somepath/icon2.png');").executeStatement();
		db.prepare("INSERT INTO Icon (iconId, path) VALUES (3, '/somepath/icon3.png');").executeStatement();

		db.prepare("INSERT INTO Person (personId, firstName, lastName, iconId, contractDocument) VALUES (1, 'Ian', 'Harrigan', 1, X'746869732069732069616e7320636f6e747261637420646f63756d656e74');")
			.executeStatement();
		db.prepare("INSERT INTO Person (personId, firstName, lastName, iconId) VALUES (2, 'Bob', 'Barker', 3);").executeStatement();
		db.prepare("INSERT INTO Person (personId, firstName, lastName, iconId) VALUES (3, 'Tim', 'Mallot', 2);").executeStatement();
		db.prepare("INSERT INTO Person (personId, firstName, lastName, iconId) VALUES (4, 'Jim', 'Parker', 1);").executeStatement();

		db.prepare("INSERT INTO Organization (organizationId, name, iconId) VALUES (1, 'ACME Inc', 2);").executeStatement();
		db.prepare("INSERT INTO Organization (organizationId, name, iconId) VALUES (2, 'Haxe LLC', 1);").executeStatement();
		db.prepare("INSERT INTO Organization (organizationId, name, iconId) VALUES (3, 'PASX Ltd', 3);").executeStatement();

		db.prepare("INSERT INTO Person_Organization (Person_personId, Organization_organizationId) VALUES (1, 1);").executeStatement();
		db.prepare("INSERT INTO Person_Organization (Person_personId, Organization_organizationId) VALUES (2, 1);").executeStatement();
		db.prepare("INSERT INTO Person_Organization (Person_personId, Organization_organizationId) VALUES (3, 1);").executeStatement();
		db.prepare("INSERT INTO Person_Organization (Person_personId, Organization_organizationId) VALUES (2, 2);").executeStatement();
		db.prepare("INSERT INTO Person_Organization (Person_personId, Organization_organizationId) VALUES (4, 2);").executeStatement();
		db.prepare("INSERT INTO Person_Organization (Person_personId, Organization_organizationId) VALUES (1, 3);").executeStatement();
		db.prepare("INSERT INTO Person_Organization (Person_personId, Organization_organizationId) VALUES (4, 3);").executeStatement();

		db.prepare("COMMIT;").executeStatement();

		db.close();
	}
}
