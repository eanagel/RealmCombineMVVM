//
//  RealmConfig.swift
//  People
//
//  Created by Ethan Nagel on 8/7/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import RealmSwift

class RealmConfig {
    private static func loadSampleData() {
        print("loading sample data...")
        
        let realm = try! Realm()
        
        try! realm.write {
            func person(_ firstName: String, _ lastName: String, _ phone: String, _ email: String) {
                let person = Person()
                person.firstName = firstName
                person.lastName = lastName
                person.phone = phone
                person.email = email
                realm.add(person)
            }
            
            person("John", "Yaya", "831-555-1212", "jyaya@yoyodyne.com")
            person("Bill", "Bixby", "201-555-1212", "thehulk@gmail.com")
            person("Michael", "Smith", "415-555-1212", "vms@mars.com")
            person("John", "Gault", "602-555-1212", "whereami@gmail.com")
            person("Han", "Solo", "505-555-1212", "ishotfirst@falcon.com")
            person("Lazurus", "Long", "123-555-1212", "thosandyearitch@gmail.com")
            person("Grace", "Hopper", "757-555-1212", "first@code.com")
            person("Diana", "Prince", "203-555-1212", "diana@paradiseisland.com")
            person("Jean", "Grey", "203-555-1212", "jean@x-men.com")
            person("Sarah", "Connor", "231-555-1212", "sarah@skynet.com")
            person("Nyota", "Uhura", "231-555-1212", "uhura@uss-enterprise.ufp.com")
            person("Leeloo", "Dallas", "231-555-1212", "leeloo.dalas@multipass.com")
        }
    }
            
    /// configures & initializes realm database instance
    static func configure() {
        
        var cfg = Realm.Configuration()
        
        // Set the realm database location to caches...
        // (we could also use application support if we want the database backed up to iCloud)
        
        cfg.fileURL = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!.appending("/default.realm"))

        // If the realm schema version changes we will delete the realm get all data from the server
        // the plan is to use this approach instead of managing migrations. It also means that data
        // in realm should be considered a cache for the most part...
        
        cfg.deleteRealmIfMigrationNeeded = true
        
        // Checks if the realm database has enough empty space to warrant compaction and, if so it will
        // do it on the first open (which we will do in a sec here...)
        
        cfg.shouldCompactOnLaunch = { totalBytes, usedBytes in
            // totalBytes refers to the size of the file on disk in bytes (data + free space)
            // usedBytes refers to the number of bytes used by data in the file

            // Compact if the file is over 100MB in size and less than 50% 'used'
            let oneHundredMB = 100 * 1024 * 1024
            print ("totalbytes \(totalBytes)")
            print ("usedbytes \(usedBytes)")
            if (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.7{
                print("will compact realm")
            }
            return (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.7
        }
        
        // Whenever we create a default realm instance it will use this configuration...
        
        Realm.Configuration.defaultConfiguration = cfg
        
        // The first time we open the realm it will delete the instance and recreate it if there are
        // significant schema changes. If the database needs to be compacted thiw will happen now as well...
        
        do {
            let realm = try Realm()
            print("REALM: \(realm.configuration.fileURL?.absoluteString ?? "Error")")
            
            if realm.isEmpty {
                loadSampleData()
            }
        } catch {
            fatalError("Failed to open realm: \(error)")
        }
    }
}
