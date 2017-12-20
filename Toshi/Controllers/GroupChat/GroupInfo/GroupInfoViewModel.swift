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

final class GroupInfoViewModel {

    let filteredDatabaseViewName = "filteredDatabaseViewName"

    private var thread: TSGroupThread

    private var groupInfo: GroupInfo {
        didSet {
            setup()

            let oldGroupInfo = oldValue
            if oldGroupInfo.participantsIDs.count != groupInfo.participantsIDs.count {
                completeActionDelegate?.groupViewModelDidRequireReload(self)
            }
        }
    }

    init(_ groupThread: TSGroupThread) {
        self.thread = groupThread
        let groupModel = groupThread.groupModel

        groupInfo = GroupInfo()
        groupInfo.title = groupModel.groupName
        groupInfo.participantsIDs = groupModel.groupMemberIds
        groupInfo.avatar = groupModel.groupImage

        setup()
    }

    private weak var completionDelegate: GroupViewModelCompleteActionDelegate?

    private var models: [TableSectionData] = []

    private func setup() {
        let avatarTitleData = TableCellData(title: groupInfo.title, leftImage: groupInfo.avatar)
        avatarTitleData.isPlaceholder = groupInfo.title.length > 0
        avatarTitleData.tag = GroupItemType.avatarTitle.rawValue

        let avatarTitleSectionData = TableSectionData(cellsData: [avatarTitleData])
        let notificationsData = TableCellData(title: Localized("new_group_notifications_settings_title"), switchState: groupInfo.notificationsOn)
        notificationsData.tag = GroupItemType.notifications.rawValue
        let settingsSectionData = TableSectionData(cellsData: [notificationsData], headerTitle: Localized("new_group_settings_header_title"))

        let participantsSectionData = setupParticipantsSection()

        let leaveGroupCellData = TableCellData(title: Localized("group_info_leave_group_title"))
        leaveGroupCellData.tag = GroupItemType.exitGroup.rawValue

        let exitGroupSectionData = TableSectionData(cellsData: [leaveGroupCellData])

        models = [avatarTitleSectionData, settingsSectionData, participantsSectionData, exitGroupSectionData]
    }

    private func setupParticipantsSection() -> TableSectionData {
        let addParticipantsData = TableCellData(title: Localized("new_group_add_participants_action_title"))
        addParticipantsData.tag = GroupItemType.addParticipant.rawValue

        var participantsCellData: [TableCellData] = [addParticipantsData]
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            CrashlyticsLogger.log("Failed to access app delegate")
            fatalError("Can't access app delegate")
        }

        let members = appDelegate.contactsManager.tokenContacts.filter { groupInfo.participantsIDs.contains($0.address) }
        let sortedMembers = members.sorted { $0.username < $1.username }

        for member in sortedMembers {
            let cellData = TableCellData(title: member.name, subtitle: member.displayUsername, leftImage: AvatarManager.shared.cachedAvatar(for: member.avatarPath))
            cellData.tag = GroupItemType.participant.rawValue
            participantsCellData.append(cellData)
        }

        if groupInfo.participantsIDs.contains(Cereal.shared.address), let user = TokenUser.current {
            let cellData = TableCellData(title: user.name, subtitle: user.displayUsername, leftImage: AvatarManager.shared.cachedAvatar(for: user.avatarPath))
            cellData.tag = GroupItemType.participant.rawValue
            participantsCellData.append(cellData)
        }

        let headerTitle = String(format: Localized("group_participants_header_title"), groupInfo.participantsIDs.count)

        return TableSectionData(cellsData: participantsCellData, headerTitle: headerTitle)
    }

    @objc private func updateGroup() {
        guard let updatedGroupModel = TSGroupModel(title: groupInfo.title, memberIds: NSMutableArray(array: groupInfo.participantsIDs), image: groupInfo.avatar, groupId: thread.groupModel.groupId) else { return }

        completeActionDelegate?.groupViewModelDidStartCreateOrUpdate()

        ChatInteractor.updateGroup(with: updatedGroupModel, completion: { [weak self] _ in
            self?.completeActionDelegate?.groupViewModelDidFinishCreateOrUpdate()
        })
    }
}

extension GroupInfoViewModel: GroupViewModelProtocol {

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
    
    func updateParticipantsIds(to participantsIds: [String]) {
        groupInfo.participantsIDs.append(contentsOf: participantsIds)
    }

    func updatePublicState(to isPublic: Bool) {
        groupInfo.isPublic = isPublic
    }

    func updateNotificationsState(to notificationsOn: Bool) {
        groupInfo.notificationsOn = notificationsOn
    }

    var groupThread: TSGroupThread? { return thread }

    var rightBarButtonSelector: Selector { return #selector(updateGroup) }

    var viewControllerTitle: String { return Localized("group_info_title") }
    var rightBarButtonTitle: String { return Localized("update_group_button_title") }
    var imagePickerTitle: String { return Localized("image-picker-select-source-title") }
    var imagePickerCameraActionTitle: String { return Localized("image-picker-camera-action-title") }
    var imagePickerLibraryActionTitle: String { return Localized("image-picker-library-action-title") }
    var imagePickerCancelActionTitle: String { return Localized("cancel_action_title") }

    var errorAlertTitle: String { return Localized("error_title") }
    var errorAlertMessage: String { return Localized("toshi_generic_error") }

    var isDoneButtonEnabled: Bool { return groupInfo.title.length > 0 }
    var participantsIDs: [String] { return groupInfo.participantsIDs }
}
