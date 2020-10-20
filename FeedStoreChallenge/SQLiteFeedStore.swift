//
//  SQLiteFeedStore.swift
//  FeedStoreChallenge
//
//  Created by Fabio Cuomo on 20/10/2020.
//  Copyright © 2020 Essential Developer. All rights reserved.
//

import Foundation

public class SQLiteFeedStore: FeedStore {
    private let db: SQLiteDatabaseWrapper
    
    public init?(dbURL: URL) throws {
        db = try SQLiteDatabaseWrapper.open(dbURL)
        try db.prepareTable()
    }
    
    public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
        do {
            try db.clearCache()
            completion(nil)
        } catch let error {
            completion(error)
        }
    }
    
    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        deleteCachedFeed { [db] error in
            do {
                try db.addNewEntry(feed, timestamp: timestamp)
                completion(nil)
            } catch let error {
                completion(error)
            }
        }
    }
    
    public func retrieve(completion: @escaping RetrievalCompletion) {
        do {
            let (entries, timestamp) = try db.cacheEntries()
            if entries.isEmpty {
                completion(.empty)
            } else {
                completion(.found(feed: entries, timestamp: timestamp))
            }
        } catch let error {
            completion(.failure(error))
        }
    }
}

