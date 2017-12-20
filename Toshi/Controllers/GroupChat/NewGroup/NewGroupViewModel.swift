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
import UIKit

final class NewGroupViewModel {

    let filteredDatabaseViewName = "filteredDatabaseViewName"

    private var groupInfo: GroupInfo {
        didSet {
            setup()

            let oldGroupInfo = oldValue
            if oldGroupInfo.participantsIDs.count != groupInfo.participantsIDs.count {
                completeActionDelegate?.groupViewModelDidRequireReload(self)
            }
        }
    }

    private var models: [TableSectionData] = []

    init(_ groupModel: TSGroupModel) {
        groupInfo = GroupInfo()
        groupInfo.title = groupModel.groupName
        groupInfo.participantsIDs = groupModel.groupMemberIds

        setup()
    }

    private weak var completionDelegate: GroupViewModelCompleteActionDelegate?

    private func setup() {
        let avatarTitleData = TableCellData(title: groupInfo.title, leftImage: groupInfo.avatar)
        avatarTitleData.isPlaceholder = groupInfo.title.length > 0
        avatarTitleData.tag = GroupItemType.avatarTitle.rawValue

        let avatarTitleSectionData = TableSectionData(cellsData: [avatarTitleData])
        let notificationsData = TableCellData(title: Localized("new_group_notifications_settings_title"), switchState: groupInfo.notificationsOn)
        notificationsData.tag = GroupItemType.notifications.rawValue
        let settingsSectionData = TableSectionData(cellsData: [notificationsData], headerTitle: Localized("new_group_settings_header_title"))

        var participantsCellData: [TableCellData] = []
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let members = appDelegate.contactsManager.tokenContacts.filter { groupInfo.participantsIDs .contains($0.address) }
        for member in members {
            participantsCellData.append(TableCellData(title: member.name, subtitle: member.displayUsername, leftImage: AvatarManager.shared.cachedAvatar(for: member.avatarPath)))
        }

        let participantsHeaderTitle = String(format: Localized("group_participants_header_title"), members.count)
        let participantsSectionData = TableSectionData(cellsData: participantsCellData, headerTitle: participantsHeaderTitle)

        models = [avatarTitleSectionData, settingsSectionData, participantsSectionData]
    }

    @objc private func createGroup() {
        groupInfo.participantsIDs.append(Cereal.shared.address)

        completeActionDelegate?.groupViewModelDidStartCreateOrUpdate()

        ChatInteractor.createGroup(with: NSMutableArray(array: groupInfo.participantsIDs), name: groupInfo.title, avatar: groupInfo.avatar, completion: { [weak self] _ in

            self?.completeActionDelegate?.groupViewModelDidFinishCreateOrUpdate()
        })
    }
}

extension NewGroupViewModel: GroupViewModelProtocol {

    var completeActionDelegate: GroupViewModelCompleteActionDelegate? {
        get {
            return completionDelegate
        }
        set {
            completionDelegate = newValue
        }
    }

    var sectionModels: [TableSectionData] {
        return models
    }

    func updateAvatar(to image: UIImage) {
        groupInfo.avatar = image
    }

    func updateTitle(to title: String) {
        groupInfo.title = title
    }

    func updatePublicState(to isPublic: Bool) {
        groupInfo.isPublic = isPublic
    }

    func updateNotificationsState(to notificationsOn: Bool) {
        groupInfo.notificationsOn = notificationsOn
    }

    func updateParticipantsIds(to participantsIds: [String]) {
        groupInfo.participantsIDs = participantsIDs
    }

    var groupThread: TSGroupThread? { return nil }

    var rightBarButtonSelector: Selector {
        return #selector(createGroup)
    }

    var viewControllerTitle: String { return Localized("new_group_title") }
    var rightBarButtonTitle: String { return Localized("create_group_button_title") }
    var imagePickerTitle: String { return Localized("image-picker-select-source-title") }
    var imagePickerCameraActionTitle: String { return Localized("image-picker-camera-action-title") }
    var imagePickerLibraryActionTitle: String { return Localized("image-picker-library-action-title") }
    var imagePickerCancelActionTitle: String { return Localized("cancel_action_title") }

    var errorAlertTitle: String { return Localized("error_title") }
    var errorAlertMessage: String { return Localized("toshi_generic_error") }

    var isDoneButtonEnabled: Bool { return groupInfo.title.length > 0 }

    var participantsIDs: [String] { return groupInfo.participantsIDs }
}
