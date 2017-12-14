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

import UIKit
import SweetFoundation
import SweetUIKit

extension NSNotification.Name {
    static let ChatDatabaseCreated = NSNotification.Name(rawValue: "ChatDatabaseCreated")
}

class RecentViewController: SweetTableController, Emptiable {

    let emptyView = EmptyView(title: Localized("chats_empty_title"), description: Localized("chats_empty_description"), buttonTitle: Localized("invite_friends_action_title"))

    lazy var mappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: [TSInboxGroup], view: TSThreadDatabaseViewExtensionName)
        mappings.setIsReversed(true, forGroup: TSInboxGroup)

        return mappings
    }()

    lazy var uiDatabaseConnection: YapDatabaseConnection = {
        let database = TSStorageManager.shared().database()!
        let dbConnection = database.newConnection()
        dbConnection.beginLongLivedReadTransaction()

        return dbConnection
    }()

    private var chatAPIClient: ChatAPIClient {
        return ChatAPIClient.shared
    }

    private var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    init() {
        super.init()

        title = "Recent"

        loadViewIfNeeded()

        if TokenUser.current != nil {
            self.loadMessages()
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(chatDBCreated(_:)), name: .ChatDatabaseCreated, object: nil)
        }
    }

    private func loadMessages() {
        uiDatabaseConnection.asyncRead { [weak self] transaction in
            self?.mappings.update(with: transaction)

            DispatchQueue.main.async {
                self?.showEmptyStateIfNeeded()
            }
        }

        registerNotifications()
    }

    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addSubviewsAndConstraints()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChatCell.self)
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.showsVerticalScrollIndicator = true
        tableView.alwaysBounceVertical = true

        emptyView.isHidden = true
    }

    @objc func emptyViewButtonPressed(_ button: ActionButton) {
        let shareController = UIActivityViewController(activityItems: ["Get Toshi, available for iOS and Android! (https://toshi.org)"], applicationActivities: [])
        Navigator.presentModally(shareController)
    }

    @objc private func chatDBCreated(_ notification: Notification) {
        loadMessages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        preferLargeTitleIfPossible(true)
        tabBarController?.tabBar.isHidden = false
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didPressCompose(_:)))
    }
    
    @objc private func didPressCompose(_ barButtonItem: UIBarButtonItem) {
        let profilesViewController = ProfilesViewController(type: .newChat, delegate: self)
        let navController = ProfilesNavigationController(rootViewController: profilesViewController)
        Navigator.presentModally(navController)
    }

    private func addSubviewsAndConstraints() {
        let tableHeaderHeight = navigationController?.navigationBar.frame.height ?? 0
        
        view.addSubview(emptyView)
        emptyView.actionButton.addTarget(self, action: #selector(emptyViewButtonPressed(_:)), for: .touchUpInside)
        emptyView.edges(to: layoutGuide(), insets: UIEdgeInsets(top: tableHeaderHeight, left: 0, bottom: 0, right: 0))
    }

    func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseDidChange(notification:)), name: .YapDatabaseModified, object: nil)
    }

    @objc func yapDatabaseDidChange(notification _: NSNotification) {
        let notifications = uiDatabaseConnection.beginLongLivedReadTransaction()

        // If changes do not affect current view, update and return without updating collection view
        // swiftlint:disable:next force_cast
        let threadViewConnection = uiDatabaseConnection.ext(TSThreadDatabaseViewExtensionName) as! YapDatabaseViewConnection

        let hasChangesForCurrentView = threadViewConnection.hasChanges(for: notifications)
        guard hasChangesForCurrentView else {
            uiDatabaseConnection.read { transaction in
                self.mappings.update(with: transaction)
            }

            return
        }

        let yapDatabaseChanges = threadViewConnection.getChangesFor(notifications: notifications, with: mappings)
        let isDatabaseChanged = yapDatabaseChanges.rowChanges.count != 0 || yapDatabaseChanges.sectionChanges.count != 0

        guard isDatabaseChanged else { return }

        if let insertedRow = yapDatabaseChanges.rowChanges.first(where: { $0.type == .insert }) {
            if let newIndexPath = insertedRow.newIndexPath {
                processNewThread(at: newIndexPath)
            }
        } else if let updatedRow = yapDatabaseChanges.rowChanges.first(where: { $0.type == .update }) {
            if let indexPath = updatedRow.indexPath {
                processUpdateThread(at: indexPath)
            }
        }

        // No need to animate the tableview if not being presented.
        // Avoids an issue where tableview will actually cause a crash on update
        // during a chat update.
        if navigationController?.topViewController == self && tabBarController?.selectedViewController == navigationController {
            tableView.beginUpdates()

            for rowChange in yapDatabaseChanges.rowChanges {

                switch rowChange.type {
                case .delete:
                    guard let indexPath = rowChange.indexPath else { continue }
                    tableView.deleteRows(at: [indexPath], with: .left)
                case .insert:
                    guard let newIndexPath = rowChange.newIndexPath else { continue }

                    updateContactIfNeeded(at: newIndexPath)
                    tableView.insertRows(at: [newIndexPath], with: .right)
                case .move:
                    guard let indexPath = rowChange.indexPath, let newIndexPath = rowChange.newIndexPath else { continue }

                    tableView.deleteRows(at: [indexPath], with: .left)
                    tableView.insertRows(at: [newIndexPath], with: .right)
                case .update:
                    guard let indexPath = rowChange.indexPath else { continue }

                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }

            tableView.endUpdates()
        } else {
            tableView.reloadData()
        }

        showEmptyStateIfNeeded()
    }

    private func processNewThread(at indexPath: IndexPath) {
        if let thread = self.thread(at: indexPath) {

            if let contactIdentifier = thread.contactIdentifier() {
                IDAPIClient.shared.updateContact(with: contactIdentifier)
            }

            if thread.isGroupThread() && ProfileManager.shared().isThread(inProfileWhitelist: thread) == false {
                ProfileManager.shared().addThread(toProfileWhitelist: thread)

                (thread as? TSGroupThread)?.groupModel.groupMemberIds.forEach { memberId in

                    idAPIClient.updateContact(with: memberId)
                    AvatarManager.shared.downloadAvatar(for: memberId)
                }
            }
        }
    }

    private func processUpdateThread(at indexPath: IndexPath) {
        if let thread = self.thread(at: indexPath) {

            if let topChatViewController = Navigator.topViewController as? ChatViewController {
                topChatViewController.updateThread(thread)
            }

            if thread.isGroupThread() && ProfileManager.shared().isThread(inProfileWhitelist: thread) == false {
                ProfileManager.shared().addThread(toProfileWhitelist: thread)

                (thread as? TSGroupThread)?.groupModel.groupMemberIds.forEach { memberId in

                    idAPIClient.updateContact(with: memberId)
                    AvatarManager.shared.downloadAvatar(for: memberId)
                }
            }
        }
    }

    private func showEmptyStateIfNeeded() {
        let shouldHideEmptyState = mappings.numberOfItems(inSection: 0) > 0

        emptyView.isHidden = shouldHideEmptyState
    }

    func updateContactIfNeeded(at indexPath: IndexPath) {
        if let thread = self.thread(at: indexPath), let address = thread.contactIdentifier() {
            DLog("Updating contact info for address: \(address).")

            idAPIClient.retrieveUser(username: address) { contact in
                if let contact = contact {
                    DLog("Updated contact info for \(contact.username)")
                }
            }
        }
    }

    func thread(at indexPath: IndexPath) -> TSThread? {
        var thread: TSThread?

        uiDatabaseConnection.read { transaction in
            guard let dbExtension = transaction.extension(TSThreadDatabaseViewExtensionName) as? YapDatabaseViewTransaction else { return }
            guard let object = dbExtension.object(at: indexPath, with: self.mappings) as? TSThread else { return }

            thread = object
        }

        return thread
    }

    func thread(withAddress address: String) -> TSThread? {
        var thread: TSThread?

        uiDatabaseConnection.read { transaction in
            transaction.enumerateRows(inCollection: TSThread.collection()) { _, object, _, stop in
                if let possibleThread = object as? TSThread {
                    if possibleThread.contactIdentifier() == address {
                        thread = possibleThread
                        stop.pointee = true
                    }
                }
            }
        }

        return thread
    }

    func thread(withIdentifier identifier: String) -> TSThread? {
        var thread: TSThread?

        uiDatabaseConnection.read { transaction in
            transaction.enumerateRows(inCollection: TSThread.collection()) { _, object, _, stop in
                if let possibleThread = object as? TSThread {
                    if possibleThread.uniqueId == identifier {
                        thread = possibleThread
                        stop.pointee = true
                    }
                }
            }
        }

        return thread
    }
}

extension RecentViewController: ProfileListDelegate {

    func viewController(_ viewController: ProfilesViewController, didSelect profile: TokenUser) {
        viewController.dismiss(animated: true, completion: nil)
        
        let selectedProfileAddress = profile.address
        ChatInteractor.getOrCreateThread(for: selectedProfileAddress)
        
        DispatchQueue.main.async {
            Navigator.tabbarController?.displayMessage(forAddress: selectedProfileAddress)
            self.dismiss(animated: true)
        }
    }
}

extension RecentViewController: UITableViewDelegate {

    func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let thread = self.thread(at: indexPath) {
            let chatViewController = ChatViewController(thread: thread)
            navigationController?.pushViewController(chatViewController, animated: true)
        }
    }

    func tableView(_: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let action = UITableViewRowAction(style: .destructive, title: "Delete") { _, indexPath in
            if let thread = self.thread(at: indexPath) {
                ChatInteractor.deleteThread(thread)
            }
        }

        return [action]
    }
}

extension RecentViewController: UITableViewDataSource {

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(mappings.numberOfItems(inSection: UInt(section)))
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(ChatCell.self, for: indexPath)
        let thread = self.thread(at: indexPath)

        // TODO: deal with last message from thread. It should be last visible message.
        cell.thread = thread

        return cell
    }
}
