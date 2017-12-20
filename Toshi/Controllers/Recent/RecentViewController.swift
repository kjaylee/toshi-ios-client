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

enum RecentContentSection: Int {
    case unacceptedThreads
    case acceptedThreads

    var title: String? {
        switch self {
        case .acceptedThreads:
            return Localized("recent_messages_section_header_title")
        default:
            return nil
        }
    }
}

final class RecentViewController: SweetTableController, Emptiable {

    private lazy var dataSource: ThreadsDataSource = {
        let dataSource = ThreadsDataSource(target: .recent)
        dataSource.output = self

        return dataSource
    }()

    let emptyView = EmptyView(title: Localized("chats_empty_title"), description: Localized("chats_empty_description"), buttonTitle: Localized("invite_friends_action_title"))

    private var chatAPIClient: ChatAPIClient {
        return ChatAPIClient.shared
    }

    private var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)

        title = dataSource.title

        loadViewIfNeeded()
    }
    
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        addSubviewsAndConstraints()

        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(ChatCell.self)
        BasicTableViewCell.register(in: tableView)

        tableView.tableFooterView = UIView(frame: .zero)
        tableView.showsVerticalScrollIndicator = true
        tableView.alwaysBounceVertical = true

        emptyView.isHidden = true

        dataSource.output = self
    }

    @objc func emptyViewButtonPressed(_ button: ActionButton) {
        let shareController = UIActivityViewController(activityItems: ["Get Toshi, available for iOS and Android! (https://toshi.org)"], applicationActivities: [])
        Navigator.presentModally(shareController)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        preferLargeTitleIfPossible(true)
        tabBarController?.tabBar.isHidden = false

        tableView.reloadData()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didPressCompose(_:)))
    }
    
    @objc private func didPressCompose(_ barButtonItem: UIBarButtonItem) {
        let datasource = ProfilesDataSource(type: .newChat)
        let profilesViewController = ProfilesNavigationController(rootViewController: ProfilesViewController(datasource: datasource, output: self))
        Navigator.presentModally(profilesViewController)
    }

    private func addSubviewsAndConstraints() {
        let tableHeaderHeight = navigationController?.navigationBar.frame.height ?? 0
        
        view.addSubview(emptyView)
        emptyView.actionButton.addTarget(self, action: #selector(emptyViewButtonPressed(_:)), for: .touchUpInside)
        emptyView.edges(to: layoutGuide(), insets: UIEdgeInsets(top: tableHeaderHeight, left: 0, bottom: 0, right: 0))
    }

    private func showEmptyStateIfNeeded() {
        let numberOfUnacceptedThreads = dataSource.unacceptedThreadsCount
        let numberOfAcceptedThreads = dataSource.acceptedThreadsCount
        let shouldHideEmptyState = (numberOfUnacceptedThreads + numberOfAcceptedThreads) > 0

        emptyView.isHidden = shouldHideEmptyState
    }

    private func messagesRequestsCell(for indexPath: IndexPath) -> UITableViewCell {
        let cellConfigurator = CellConfigurator()
        var cellData: TableCellData
        var cell = UITableViewCell(frame: .zero)

        if let firstUnacceptedThread = dataSource.unacceptedThread(at: IndexPath(row: 0, section: 0)) {
            let firstImage = threadImage(for: firstUnacceptedThread) ?? UIImage(named: "avatar-placeholder")!

            if let secondUnacceptedThread = dataSource.unacceptedThread(at: IndexPath(row: 1, section: 0)) {

                let secondImage = threadImage(for: secondUnacceptedThread) ?? UIImage(named: "avatar-placeholder")!

                cellData = TableCellData(title: Localized("messages_requests_title"), subtitle: Localized("message_requests_description"), doubleImage: (firstImage: firstImage, secondImage: secondImage))

                cell = tableView.dequeueReusableCell(withIdentifier: cellConfigurator.cellIdentifier(for: cellData.components), for: indexPath)
                cellConfigurator.configureCell(cell, with: cellData)
                cell.accessoryType = .disclosureIndicator

                return cell
            }

            cellData = TableCellData(title: Localized("messages_requests_title"), subtitle: Localized("message_requests_description"), leftImage: firstImage)
            cell = tableView.dequeueReusableCell(withIdentifier: cellConfigurator.cellIdentifier(for: cellData.components), for: indexPath)
            cellConfigurator.configureCell(cell, with: cellData)
        }

        return cell
    }

    func updateContactIfNeeded(at indexPath: IndexPath) {
        if let thread = dataSource.acceptedThread(at: indexPath.row, in: 0), let address = thread.contactIdentifier() {
            DLog("Updating contact info for address: \(address).")

            idAPIClient.retrieveUser(username: address) { contact in
                if let contact = contact {
                    DLog("Updated contact info for \(contact.username)")
                }
            }
        }
    }

    func thread(withAddress address: String) -> TSThread? {
        return dataSource.thread(withAddress: address)
    }

    func thread(withIdentifier identifier: String) -> TSThread? {
        return dataSource.thread(withIdentifier: identifier)
    }
}

extension RecentViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        var sectionCount = 0

        if dataSource.unacceptedThreadsCount > 0 {
            sectionCount += 1
        }

        if dataSource.acceptedThreadsCount > 0 {
            sectionCount += 1
        }

        return sectionCount
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && dataSource.unacceptedThreadsCount > 0 {
            return nil
        }

        return Localized("recent_messages_section_header_title")
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {

        var numberOfRows = 0
        let contentSection = RecentContentSection(rawValue: section)

        if contentSection == .unacceptedThreads && dataSource.unacceptedThreadsCount > 0 {
            numberOfRows = 1
        } else {
            numberOfRows = dataSource.acceptedThreadsCount
        }

        return numberOfRows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell = UITableViewCell(frame: .zero)

        let contentSection = RecentContentSection(rawValue: indexPath.section)

        let isMessagesRequestsRow = dataSource.unacceptedThreadsCount > 0 && contentSection == .unacceptedThreads
        if isMessagesRequestsRow {
            cell = messagesRequestsCell(for: indexPath)
        } else if let thread = dataSource.acceptedThread(at: indexPath.row, in: 0) {
            let threadCellConfigurator = ThreadCellConfigurator(thread: thread)
            let cellData = threadCellConfigurator.cellData
            cell = tableView.dequeueReusableCell(withIdentifier: AvatarTitleSubtitleDetailsBadgeCell.reuseIdentifier, for: indexPath)

            threadCellConfigurator.configureCell(cell, with: cellData)
        }

        cell.accessoryType = .disclosureIndicator
        
        return cell
    }

    func threadImage(for thread: TSThread) -> UIImage? {
        if thread.isGroupThread() {
            return (thread as? TSGroupThread)?.groupModel.groupImage
        } else {
            return thread.image()
        }
    }
}

extension RecentViewController: ThreadsDataSourceOutput {

    func threadsDataSourceDidLoad() {
        tableView.reloadData()
        showEmptyStateIfNeeded()
    }
}

extension RecentViewController: ProfilesListCompletionOutput {

    func didFinish(_ controller: ProfilesViewController, selectedProfilesIds: [String]) {
        controller.dismiss(animated: true, completion: nil)

        guard let selectedProfileAddress = selectedProfilesIds.first else { return }

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
        tableView.deselectRow(at: indexPath, animated: true)

        guard let contentSection = RecentContentSection(rawValue: indexPath.section) else { return }

        switch contentSection {
        case .unacceptedThreads:
            if dataSource.unacceptedThreadsCount > 0 {
                let messagesRequestsViewController = MessagesRequestsViewController(style: .grouped)
                navigationController?.pushViewController(messagesRequestsViewController, animated: true)
            } else {
                guard let thread = dataSource.acceptedThread(at: indexPath.row, in: 0) else { return }
                let chatViewController = ChatViewController(thread: thread)
                navigationController?.pushViewController(chatViewController, animated: true)
            }
        case .acceptedThreads:
            guard let thread = dataSource.acceptedThread(at: indexPath.row, in: 0) else { return }
            let chatViewController = ChatViewController(thread: thread)
            navigationController?.pushViewController(chatViewController, animated: true)
        }
    }

    func tableView(_: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let action = UITableViewRowAction(style: .destructive, title: "Delete") { _, indexPath in
            if let thread = self.dataSource.acceptedThread(at: indexPath.row, in: 0) {

                ChatInteractor.deleteThread(thread)
            }
        }

        return [action]
    }
}
