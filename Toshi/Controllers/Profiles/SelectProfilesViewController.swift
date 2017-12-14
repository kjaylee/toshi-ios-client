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

import TinyConstraints
import UIKit

protocol SelectProfilesViewControllerDelegate: class {
    
    func viewController(_ viewController: SelectProfilesViewController, didSelect profileIds: [String])
}

// A view controller to allow selection of an arbitrary number of profiles.
final class SelectProfilesViewController: UIViewController {
    
    var selectedProfiles = [TokenUser]() {
        didSet {
            updateUIFromSelectedProfiles()
        }
    }
    
    enum SelectionType {
        case
        newGroupChat,
        updateGroupChat
        
        var title: String {
            switch self {
            case .newGroupChat:
                return Localized("profiles_navigation_title_new_group_chat")
            case .updateGroupChat:
                return Localized("profiles_navigation_title_update_group_chat")
            }
        }
    }
    
    weak var delegate: SelectProfilesViewControllerDelegate?
    var type: SelectionType = .newGroupChat {
        didSet {
            title = type.title
        }
    }
    
    private lazy var collectionViewLayout: UICollectionViewLayout = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        let minSpacing: CGFloat = 4
        flowLayout.minimumLineSpacing = minSpacing
        flowLayout.minimumInteritemSpacing = minSpacing
        return flowLayout
    }()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        return collectionView
    }()

    private lazy var collectionViewDataSource = SelectProfilesCollectionViewDataSource(with: collectionView, searchDelegate: self)

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.hideEmptyRows()
        
        return tableView
    }()
    
    private(set) lazy var tableViewDataSource = SelectProfilesTableViewDataSource(with: tableView, selectionDelegate: self)

    private lazy var doneButton: UIBarButtonItem = {
        let barButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone(_:)))
        barButton.isEnabled = false
        
        return barButton
    }()
    
    // MARK: - Initialization
    
    convenience init(type: SelectionType, delegate: SelectProfilesViewControllerDelegate?) {
        self.init()
        self.type = type
        self.delegate = delegate
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = type.title
        
        setupCollectionView()
        setupTableView()
        
        edgesForExtendedLayout = []
        
        navigationItem.rightBarButtonItem = doneButton
    }
    
    // MARK: - View Setup
    
    private func setupCollectionView() {
        view.addSubview(collectionView)

        collectionView.edgesToSuperview(excluding: .bottom)
        collectionView.backgroundColor = Theme.inputFieldBackgroundColor
        collectionView.height(min: 44, max: CGFloat.greatestFiniteMagnitude, priority: .defaultHigh, isActive: true)
        collectionViewDataSource.update(with: selectedProfiles)
    }
    
    private func setupTableView() {
        view.addSubview(tableView)

        tableView.edgesToSuperview(excluding: .top)
        tableView.topToBottom(of: collectionView)
        tableViewDataSource.update(with: selectedProfiles)
    }
    
    // MARK: - Updating
    
    private func updateUIFromSelectedProfiles() {
        tableViewDataSource.update(with: selectedProfiles)
        collectionViewDataSource.update(with: selectedProfiles)
        
        doneButton.isEnabled = rightBarButtonEnabled()
    }
    
    // MARK: - Action targets
    
    @objc private func didTapDone(_ button: UIBarButtonItem) {
        guard selectedProfiles.count > 0 else {
            assertionFailure("No selected profiles?!")
            
            return
        }
        
        let membersIdsArray = selectedProfiles.sorted { $0.username < $1.username }.map { $0.address }
        
        switch type {
        case .updateGroupChat:
            navigationController?.popViewController(animated: true)
            delegate?.viewController(self, didSelect: membersIdsArray)
        case .newGroupChat:
            guard let groupModel = TSGroupModel(title: "", memberIds: NSMutableArray(array: membersIdsArray), image: UIImage(named: "avatar-edit"), groupId: nil) else { return }
            
            let viewModel = NewGroupViewModel(groupModel)
            let groupViewController = GroupViewController(viewModel, configurator: NewGroupConfigurator())
            navigationController?.pushViewController(groupViewController, animated: true)
        }
    }
    
    func rightBarButtonEnabled() -> Bool {
        switch type {
        case .newGroupChat:
            // There must be at least two other people to form a new group
            return selectedProfiles.count >= 2
        case .updateGroupChat:
            // You can only update the chat if you're actually adding at least one new person.
            return selectedProfiles.count >= 1
        }
    }
}

// MARK: - Profile Search Delegate

extension SelectProfilesViewController: ProfileSearchDelegate {
    
    func enteredText(_ text: String?) {
        DLog("Text is now: \(String(describing: text))")
    }
}

// MARK: - Select Profiles Delegate

extension SelectProfilesViewController: SelectProfilesDelegate {
    
    func selected(profile: TokenUser) {
        guard !selectedProfiles.contains(profile) else {
            // Profile is already added.
            return
        }
        
        selectedProfiles.append(profile)
        updateUIFromSelectedProfiles()
    }
    
    func deselected(profile: TokenUser) {
        guard let indexToRemove = selectedProfiles.index(of: profile) else {
            // Nothing to remove.
            return
        }
        
        selectedProfiles.remove(at: indexToRemove)
        updateUIFromSelectedProfiles()
    }
}
