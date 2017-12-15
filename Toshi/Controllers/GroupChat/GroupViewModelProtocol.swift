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

enum GroupItemType: Int {
    case avatarTitle
    case notifications
    case isPublic
    case participant
    case addParticipant
}

struct GroupInfo {
    let placeholder = Localized("new_group_title")
    var title: String = ""
    var avatar = UIImage(named: "avatar-placeholder")!
    var isPublic = false
    var notificationsOn = true
    var participantsIDs: [String] = []
}

protocol GroupViewModelCompleteActionDelegate: class {

    func groupViewModelDidFinishCreateOrUpdate()
}

protocol GroupViewModelProtocol: class {

    var sectionModels: [TableSectionData] { get }
    var viewControllerTitle: String { get }
    var rightBarButtonTitle: String { get }
    var imagePickerTitle: String { get }
    var imagePickerCameraActionTitle: String { get }
    var imagePickerLibraryActionTitle: String { get }
    var imagePickerCancelActionTitle: String { get }

    var errorAlertTitle: String { get }
    var errorAlertMessage: String { get }

    var rightBarButtonSelector: Selector { get }

    var participantsIDs: [String] { get }

    func updateAvatar(to image: UIImage)
    func updatePublicState(to isPublic: Bool)
    func updateNotificationsState(to notificationsOn: Bool)
    func updateTitle(to title: String)
    func updateParticipantsIds(to participantsIds: [String])

    var isDoneButtonEnabled: Bool { get }

    var completeActionDelegate: GroupViewModelCompleteActionDelegate? { get set }
}
