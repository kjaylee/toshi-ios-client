// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

protocol ProfilesDataControllerChangesOutput: class {
    func dataControllerDidChange(_ dataController: ProfilesDataController, yapDatabaseChanges: [YapDatabaseViewRowChange])
}

// Database access centralization for displaying lists of profiles.
final class ProfilesDataController {
    
    private let filteredProfilesKey = "Filtered_Profiles_Key"
    private let customFilteredProfilesKey = "Custom_Filtered_Profiles_Key"
    
    var changesOutput: ProfilesDataControllerChangesOutput?
    
    private var allProfiles: [TokenUser] = []
    
    var excludedProfilesIds: [String] = [] {
        didSet {
            guard Yap.isUserSessionSetup else { return }
            
            adjustToExclusions()
        }
    }
    
    var isEmpty: Bool {
        let currentItemCount = mappings.numberOfItems(inSection: 0)
        return (currentItemCount == 0)
    }
    
    var searchText: String = "" {
        didSet {
            searchDatabaseConnection.readWrite { [weak self] transaction in
                guard
                    let strongSelf = self,
                    let filterTransaction = transaction.ext(strongSelf.filteredProfilesKey) as? YapDatabaseFilteredViewTransaction else { return }
                
                let tag = Date().timeIntervalSinceReferenceDate
                filterTransaction.setFiltering(strongSelf.filtering, versionTag: String(describing: tag))
            }
        }
    }
    
    private(set) lazy var uiDatabaseConnection: YapDatabaseConnection = {
        let database = Yap.sharedInstance.database
        let dbConnection = database!.newConnection()
        dbConnection.beginLongLivedReadTransaction()
        
        return dbConnection
    }()
    
    private lazy var searchDatabaseConnection: YapDatabaseConnection = {
        let database = Yap.sharedInstance.database
        let dbConnection = database!.newConnection()
        
        return dbConnection
    }()
    
    private lazy var customFilterDatabaseConnection: YapDatabaseConnection = {
        let database = Yap.sharedInstance.database
        let dbConnection = database!.newConnection()
        
        return dbConnection
    }()
    
    private var customFiltering: YapDatabaseViewFiltering {
        
        let filteringBlock: YapDatabaseViewFilteringWithObjectBlock = { [weak self] transaction, group, colelction, key, object in
            guard let strongSelf = self else { return true }
            guard let data = object as? Data, let deserialised = (try? JSONSerialization.jsonObject(with: data, options: [])), var json = deserialised as? [String: Any], let address = json[TokenUser.Constants.address] as? String else { return false }
            
            return !strongSelf.excludedProfilesIds.contains(address)
        }
        
        return YapDatabaseViewFiltering.withObjectBlock(filteringBlock)
    }
    
    private var filtering: YapDatabaseViewFiltering {
        
        let filteringBlock: YapDatabaseViewFilteringWithObjectBlock = { transaction, group, colelction, key, object in
            guard self.searchText.length > 0 else { return true }
            guard let data = object as? Data, let deserialised = (try? JSONSerialization.jsonObject(with: data, options: [])), var json = deserialised as? [String: Any], let username = json[TokenUser.Constants.username] as? String else { return false }
            
            return username.lowercased().contains(self.searchText.lowercased())
        }
        
        return YapDatabaseViewFiltering.withObjectBlock(filteringBlock)
    }
    
    private lazy var customFilteredView = YapDatabaseFilteredView(parentViewName: TokenUser.viewExtensionName, filtering: customFiltering)
    private lazy var filteredView = YapDatabaseFilteredView(parentViewName: customFilteredProfilesKey, filtering: filtering)
    
    private(set) lazy var mappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: [TokenUser.favoritesCollectionKey], view: self.filteredProfilesKey)
        mappings.setIsReversed(true, forGroup: TokenUser.favoritesCollectionKey)
        
        return mappings
    }()
    
    // MARK: - Initialization
    
    init() {
        
        if Yap.isUserSessionSetup {
            prepareDatabaseViews()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseDidChange(notification:)), name: .YapDatabaseModified, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userCreated(_:)), name: .userCreated, object: nil)

    }
    
    // MARK: - Database Setup
    
    private func prepareDatabaseViews() {
        registerTokenContactsDatabaseView()
        
        uiDatabaseConnection.read { [weak self] transaction in
            self?.mappings.update(with: transaction)
        }
        
        setupAllProfilesCollection()
    }
    
    private func contactSorting() -> YapDatabaseViewSorting {
        let viewSorting = YapDatabaseViewSorting.withObjectBlock { (_, _, _, _, object1, _, _, object2) -> ComparisonResult in
            if let data1 = object1 as? Data, let data2 = object2 as? Data,
                let contact1 = TokenUser.user(with: data1),
                let contact2 = TokenUser.user(with: data2) {
                
                return contact1.username.compare(contact2.username)
            }
            
            return .orderedAscending
        }
        
        return viewSorting
    }
    
    @discardableResult
    private func registerTokenContactsDatabaseView() -> Bool {
        guard let database = Yap.sharedInstance.database else { fatalError("couldn't instantiate the database") }
        // Check if it's already registered.
        
        let viewGrouping = YapDatabaseViewGrouping.withObjectBlock { (_, _, _, object) -> String? in
            if (object as? Data) != nil {
                return TokenUser.favoritesCollectionKey
            }
            
            return nil
        }
        
        let viewSorting = contactSorting()
        
        let options = YapDatabaseViewOptions()
        options.allowedCollections = YapWhitelistBlacklist(whitelist: Set([TokenUser.favoritesCollectionKey]))
        
        let databaseView = YapDatabaseAutoView(grouping: viewGrouping, sorting: viewSorting, versionTag: "1", options: options)
        
        var mainViewIsRegistered = database.registeredExtension(TokenUser.viewExtensionName) != nil
        if !mainViewIsRegistered {
            mainViewIsRegistered = database.register(databaseView, withName: TokenUser.viewExtensionName)
        }
        
        var customFilteredViewIsRegistered = database.registeredExtension(customFilteredProfilesKey) != nil
        if !customFilteredViewIsRegistered {
            customFilteredViewIsRegistered = database.register(customFilteredView, withName: customFilteredProfilesKey)
        }
        
        let filteredViewIsRegistered = database.register(filteredView, withName: filteredProfilesKey)
        
        return mainViewIsRegistered && customFilteredViewIsRegistered && filteredViewIsRegistered
    }
    
    private func setupAllProfilesCollection() {
        let profilesCount = Int(mappings.numberOfItems(inSection: UInt(0)))
        
        for profileIndex in 0 ..< profilesCount {
            guard let profile = profile(at: IndexPath(row: profileIndex, section: 0)) else { return }
            
            allProfiles.append(profile)
        }
    }

    private func adjustToExclusions() {
        customFilterDatabaseConnection.readWrite { [weak self] transaction in
            guard
                let strongSelf = self,
                let filterTransaction = transaction.ext(strongSelf.customFilteredProfilesKey) as? YapDatabaseFilteredViewTransaction else { return }
            
            let tag = Date().timeIntervalSinceReferenceDate
            filterTransaction.setFiltering(strongSelf.customFiltering, versionTag: String(describing: tag))
        }
    }
    
    // MARK: - Notification handling
    
    @objc private func userCreated(_ notification: Notification) {
        DispatchQueue.main.async {
            guard Yap.isUserSessionSetup else { return }
            
            self.prepareDatabaseViews()
            self.adjustToExclusions()
        }
    }
    
    @objc private func yapDatabaseDidChange(notification _: Notification) {
        let notifications = uiDatabaseConnection.beginLongLivedReadTransaction()
        
        // swiftlint:disable:next force_cast
        let threadViewConnection = uiDatabaseConnection.ext(self.filteredProfilesKey) as! YapDatabaseViewConnection
        
        if !threadViewConnection.hasChanges(for: notifications) {
            uiDatabaseConnection.read { [weak self] transaction in
                self?.mappings.update(with: transaction)
            }
            
            return
        }
        
        let yapDatabaseChanges = threadViewConnection.getChangesFor(notifications: notifications, with: mappings)
        let isDatabaseChanged = yapDatabaseChanges.rowChanges.count != 0 || yapDatabaseChanges.sectionChanges.count != 0
        
        guard isDatabaseChanged else { return }
        
        self.changesOutput?.dataControllerDidChange(self, yapDatabaseChanges: yapDatabaseChanges.rowChanges)
    }
    
    // MARK: Table View Helpers
    
    func numberOfSections() -> Int {
        return Int(mappings.numberOfSections())
    }
    
    func numberOfItems(in section: Int) -> Int {
        return Int(mappings.numberOfItems(inSection: UInt(section)))
    }

    func profile(at indexPath: IndexPath) -> TokenUser? {
        var profile: TokenUser?
        
        uiDatabaseConnection.read { [weak self] transaction in
            guard
                let strongSelf = self,
                let dbExtension: YapDatabaseViewTransaction = transaction.extension(strongSelf.filteredProfilesKey) as? YapDatabaseViewTransaction,
                let data = dbExtension.object(at: indexPath, with: strongSelf.mappings) as? Data else { return }
            
            profile = TokenUser.user(with: data, shouldUpdate: false)
        }
        
        return profile
    }
    
    // MARK: Restoration Helper
    
    func profile(for address: String, completion: @escaping ((TokenUser?) -> Void)) {
        uiDatabaseConnection.read { transaction in
            guard
                let data = transaction.object(forKey: address, inCollection: TokenUser.favoritesCollectionKey) as? Data,
                let user = TokenUser.user(with: data) else {
                    completion(nil)
                    return
            }
        
            completion(user)
        }
    }
}
