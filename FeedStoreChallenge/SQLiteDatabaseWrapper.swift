//
//  SQLiteDatabaseWrapper.swift
//  FeedStoreChallenge
//
//  Created by Fabio Cuomo on 19/10/2020.
//  Copyright © 2020 Essential Developer. All rights reserved.
//

import Foundation
import SQLite3

public enum SQLiteError: Error {
    case openDatabase(message: String)
    case createTable(message: String)
    case prepare(message: String)
    case query(message: String)
    case unknownError
}

public class SQLiteDatabaseWrapper {
    private var dbPointer: OpaquePointer? = nil
    internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var errorMessage: String {
        if let errorPointer = sqlite3_errmsg(dbPointer) {
            let errorMessage = String(cString: errorPointer)
            return errorMessage
        } else {
            return "No error message provided from sqlite."
        }
    }
    
    private init(dbPointer: OpaquePointer?) {
        self.dbPointer = dbPointer
    }
    
    deinit {
        sqlite3_close(dbPointer)
    }
    
    public func prepareTable() throws {
        let createTableSQL = """
                                CREATE TABLE IF NOT EXISTS FeedImageCache (
                                  id VARCHAR(20) PRIMARY KEY NOT NULL,
                                  description VARCHAR(255),
                                  location VARCHAR(255),
                                  url VARCHAR(255),
                                  timestamp REAL
                                );
                                """
        var statement: OpaquePointer?
        if sqlite3_exec(dbPointer, createTableSQL, nil, &statement, nil) != SQLITE_OK {
            if let sqlError = sqlite3_errmsg(dbPointer) {
                let errmsg = String(cString: sqlError)
                throw SQLiteError.prepare(message: errmsg)
            }
        }
        sqlite3_finalize(statement)
    }
    
    public func cacheEntries() throws -> ([LocalFeedImage], Date)? {
        var items = [LocalFeedImage]()
        let queryStatement = "SELECT * FROM FeedImageCache"
        let statement = try prepareStatement(sql: queryStatement)
        var timestamp: Date?
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let uuid = uuid(from: sqlite3_column_text(statement, 0)),
                  let description = sqlite3_column_text(statement, 1),
                  let location = sqlite3_column_text(statement, 2),
                  let url = url(from: sqlite3_column_text(statement, 3)) else {
                throw SQLiteError.query(message: errorMessage)
            }
            let item = LocalFeedImage(id: uuid,
                                      description: string(from: description),
                                      location: string(from: location),
                                      url: url)
            items.append(item)
            if timestamp == nil {
                timestamp = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 4))
            }
        }
        sqlite3_finalize(statement)
        guard !items.isEmpty,
              let cacheTimestamp = timestamp else { return nil }
        return (items, cacheTimestamp)
    }
    
    public func addNewEntry(_ feeds: [LocalFeedImage], timestamp: Date) throws {
        let insertSql = "INSERT INTO FeedImageCache VALUES (?, ?, ?, ?, ?);"

        try feeds.forEach { feed in
            let insertStatement = try prepareStatement(sql: insertSql)
            guard sqlite3_bind_text(insertStatement, 1, feed.id.uuidString, -1, SQLITE_TRANSIENT) == SQLITE_OK  &&
                    sqlite3_bind_text(insertStatement, 2, feed.description ?? "", -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                    sqlite3_bind_text(insertStatement, 3, feed.location ?? "", -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                    sqlite3_bind_text(insertStatement, 4, feed.url.absoluteString, -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                    sqlite3_bind_double(insertStatement, 5, timestamp.timeIntervalSinceReferenceDate) == SQLITE_OK
            else {
                throw SQLiteError.query(message: errorMessage)
            }
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                sqlite3_finalize(insertStatement)
            } else {
                throw SQLiteError.query(message: errorMessage)
            }
        }
    }
    
    public func clearCache() throws {
        let deleteSql = "DELETE FROM FeedImageCache;"

        let deleteStatement = try prepareStatement(sql: deleteSql)
        if sqlite3_step(deleteStatement) == SQLITE_DONE {
            sqlite3_finalize(deleteStatement)
        } else {
            throw SQLiteError.query(message: errorMessage)
        }
    }

    public static func open(_ dbURL: URL) throws -> SQLiteDatabaseWrapper {
        var dbPointer: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &dbPointer, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(dbPointer)
            dbPointer = nil
            if let errorPointer = sqlite3_errmsg(dbPointer) {
                let message = String(cString: errorPointer)
                throw SQLiteError.openDatabase(message: message)
            } else {
                throw SQLiteError.unknownError
            }
        }
        return SQLiteDatabaseWrapper(dbPointer: dbPointer)
    }
    
    //: MARK - Private methods
    private func prepareStatement(sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: errorMessage)
        }
        return statement
    }

    private func string(from column: UnsafePointer<UInt8>) -> String {
        String(cString: column)
    }
    
    private func uuid(from column: UnsafePointer<UInt8>) -> UUID? {
        UUID(uuidString: string(from: column))
    }
    
    private func url(from column: UnsafePointer<UInt8>) -> URL? {
        URL(string: string(from: column))
    }
    
}
