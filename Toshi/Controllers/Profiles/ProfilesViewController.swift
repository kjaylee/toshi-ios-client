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

// MARK: - Profiles View Controller Type

enum ProfilesViewControllerType {
    case favorites
    case newChat
    
    var title: String {
        switch self {
        case .favorites:
            return Localized("profiles_navigation_title_favorites")
        case .newChat:
            return Localized("profiles_navigation_title_new_chat")
        }
    }
}

protocol ProfileListDelegate: class {
    func viewController(_ viewController: ProfilesViewController, didSelect profile: TokenUser)
}

// MARK: - Profiles View Controller

final class ProfilesViewController: UITableViewController, Emptiable {
    
    let type: ProfilesViewControllerType

    var scrollViewBottomInset: CGFloat = 0
    private weak var delegate: ProfileListDelegate?

    let emptyView = EmptyView(title: Localized("favorites_empty_title"), description: Localized("favorites_empty_description"), buttonTitle: Localized("invite_friends_action_title"))
    
    var scrollView: UIScrollView {
        return tableView
    }

    // MARK: - Lazy Vars
    
    private lazy var cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancel(_:)))
    private lazy var addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAdd(_:)))

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.dimsBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        controller.searchBar.delegate = self
        controller.searchBar.barTintColor = Theme.viewBackgroundColor
        controller.searchBar.tintColor = Theme.tintColor
        controller.searchBar.placeholder = "Search by username"
        
        guard #available(iOS 11.0, *) else {
            controller.searchBar.searchBarStyle = .minimal
            controller.searchBar.backgroundColor = Theme.viewBackgroundColor
            controller.searchBar.layer.borderWidth = .lineHeight
            controller.searchBar.layer.borderColor = Theme.borderColor.cgColor
            
            return controller
        }
        
        let searchField = controller.searchBar.value(forKey: "searchField") as? UITextField
        searchField?.backgroundColor = Theme.inputFieldBackgroundColor
        
        return controller
    }()

    private(set) var dataController = ProfilesDataController()
    
    // MARK: - Initialization
    
    init(type: ProfilesViewControllerType, delegate: ProfileListDelegate?) {
        self.type = type
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        
        title = type.title
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ProfileCell.self)

        setupTableHeader()
        setupNavigationBarButtons()

        definesPresentationContext = true

        tableView.estimatedRowHeight = 80
        tableView.backgroundColor = Theme.viewBackgroundColor
        tableView.separatorStyle = .none

        let appearance = UIButton.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        appearance.setTitleColor(Theme.greyTextColor, for: .normal)
        
        displayContacts()
        setupEmptyView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        preferLargeTitleIfPossible(true)
        showOrHideEmptyState()
        
        dataController.excludedProfilesIds = []
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        scrollViewBottomInset = tableView.contentInset.bottom
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        for view in searchController.searchBar.subviews {
            view.clipsToBounds = false
        }
        searchController.searchBar.superview?.clipsToBounds = false
    }

    public override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let profile = dataController.profile(at: indexPath) else { return }
        
        didSelectProfile(profile: profile)
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return dataController.numberOfSections()
    }

    public override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataController.numberOfItems(in: section)
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(ProfileCell.self, for: indexPath)
        
        guard let profile = dataController.profile(at: indexPath) else {
            assertionFailure("Could not get profile at indexPath: \(indexPath)")
            return cell
        }

        cell.avatarPath = profile.avatarPath
        cell.name = profile.name
        cell.displayUsername = profile.displayUsername

        return cell
    }

    private func didSelectProfile(profile: TokenUser) {
        searchController.searchBar.resignFirstResponder()

        switch type {
        case .newChat:
            delegate?.viewController(self, didSelect: profile)
        case .favorites:
            navigationController?.pushViewController(ProfileViewController(profile: profile), animated: true)
            UserDefaultsWrapper.selectedContact = profile.address
        }
    }
    
    // MARK: - View Setup

    private func setupTableHeader() {
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
            tableView.tableHeaderView = ProfilesHeaderView(type: type, delegate: self)
        } else {
            tableView.tableHeaderView = ProfilesHeaderView(with: searchController.searchBar, type: type, delegate: self)

            if Navigator.topViewController == self {
                tableView.layoutIfNeeded()
            }
        }
    }
    
    private func setupEmptyView() {
        view.addSubview(emptyView)
        emptyView.actionButton.addTarget(self, action: #selector(emptyViewButtonPressed(_:)), for: .touchUpInside)
        emptyView.edges(to: layoutGuide())
        showOrHideEmptyState()
    }
    
    private func setupNavigationBarButtons() {
        switch type {
        case .newChat:
            navigationItem.leftBarButtonItem = cancelButton
        case .favorites:
            navigationItem.rightBarButtonItem = addButton
        }
    }

    private func displayContacts() {
        reloadData()
        showOrHideEmptyState()
    }
    
    // MARK: - Action Handling
    
    @objc func emptyViewButtonPressed(_ button: ActionButton) {
        let shareController = UIActivityViewController(activityItems: [Localized("sharing_action_item")], applicationActivities: [])
        Navigator.presentModally(shareController)
    }
    
    private func showOrHideEmptyState() {
        let emptyViewHidden = (searchController.isActive || !dataController.isEmpty)
        emptyView.isHidden = emptyViewHidden
        tableView.tableHeaderView?.isHidden = !emptyViewHidden
    }
    
    @objc private func didTapCancel(_ button: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    @objc private func didTapAdd(_ button: UIBarButtonItem) {
        let addContactSheet = UIAlertController(title: Localized("favorites_add_title"), message: nil, preferredStyle: .actionSheet)
        
        addContactSheet.addAction(UIAlertAction(title: Localized("favorites_add_by_username"), style: .default, handler: { _ in
            self.searchController.searchBar.becomeFirstResponder()
        }))
        
        addContactSheet.addAction(UIAlertAction(title: Localized("invite_friends_action_title"), style: .default, handler: { _ in
            let shareController = UIActivityViewController(activityItems: ["Get Toshi, available for iOS and Android! (https://www.toshi.org)"], applicationActivities: [])
            
            Navigator.presentModally(shareController)
        }))
        
        addContactSheet.addAction(UIAlertAction(title: Localized("favorites_scan_code"), style: .default, handler: { _ in
            guard let tabBarController = self.tabBarController as? TabBarController else { return }
            tabBarController.switch(to: .scanner)
        }))
        
        addContactSheet.addAction(UIAlertAction(title: Localized("cancel_action_title"), style: .cancel, handler: nil))
        
        addContactSheet.view.tintColor = Theme.tintColor
        present(addContactSheet, animated: true)
    }

    // MARK: - Table View Reloading

    func reloadData() {
        if #available(iOS 11.0, *) {
            // Must perform batch updates on iOS 11 or you'll get super-wonky layout because of the headers.
            tableView?.performBatchUpdates({
                self.tableView?.reloadData()
            }, completion: nil)
        } else {
            tableView?.reloadData()
        }
    }
}

// MARK: - Search Bar Delegate

extension ProfilesViewController: UISearchBarDelegate {
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        
        if type != .newChat {
            displayContacts()
        }
    }
}

// MARK: - Search Results Updating

extension ProfilesViewController: UISearchResultsUpdating {
    
    public func updateSearchResults(for searchController: UISearchController) {

        self.dataController.searchText = searchController.searchBar.text ?? ""
    }
}

// MARK: - Profiles Add Group Header Delegate

extension ProfilesViewController: ProfilesAddGroupHeaderDelegate {
    
    func newGroup() {
        let groupChatSelection = SelectProfilesViewController()
        groupChatSelection.title = Localized("profiles_navigation_title_new_group_chat")
        navigationController?.pushViewController(groupChatSelection, animated: true)
    }
}

extension ProfilesViewController: ProfilesDataControllerChangesOutput {

    func dataControllerDidChange(_ dataController: ProfilesDataController, yapDatabaseChanges: [YapDatabaseViewRowChange]) {
        if navigationController?.topViewController == self && tabBarController?.selectedViewController == navigationController && tableView.superview != nil {
            
            tableView?.beginUpdates()

            for rowChange in yapDatabaseChanges {

                switch rowChange.type {
                case .delete:
                    guard let indexPath = rowChange.indexPath else { continue }
                    tableView?.deleteRows(at: [indexPath], with: .none)
                case .insert:
                    guard let newIndexPath = rowChange.newIndexPath else { continue }
                    tableView?.insertRows(at: [newIndexPath], with: .none)
                case .move:
                    guard let newIndexPath = rowChange.newIndexPath, let indexPath = rowChange.indexPath else { continue }
                    tableView?.deleteRows(at: [indexPath], with: .none)
                    tableView?.insertRows(at: [newIndexPath], with: .none)
                case .update:
                    guard let indexPath = rowChange.indexPath else { continue }
                    tableView?.reloadRows(at: [indexPath], with: .none)
                }
            }

            tableView?.endUpdates()
        } else {
            tableView.reloadData()
        }
    }
}
