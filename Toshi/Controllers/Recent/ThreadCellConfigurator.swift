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

final class ThreadCellConfigurator: CellConfigurator {

    private var thread: TSThread

    lazy var messageAttributes: [NSAttributedStringKey: Any] = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2.5
        paragraphStyle.paragraphSpacing = -4
        paragraphStyle.lineBreakMode = .byTruncatingTail

        return [
            .kern: -0.4,
            .font: Theme.preferredRegularSmall(),
            .foregroundColor: Theme.greyTextColor,
            .paragraphStyle: paragraphStyle
        ]
    }()

    init(thread: TSThread) {
        self.thread = thread
    }

    lazy var cellData: TableCellData = {
        var avatar: UIImage?
        var subtitle = "..."
        var title = ""
        var details: String?
        var badgeText: String?

        if thread.isGroupThread() {
            avatar = (thread as? TSGroupThread)?.groupModel.groupImage ?? UIImage(named: "avatar-placeholder")
            title = thread.name()
        } else if let recipient = self.recipient(for: thread) {
            avatar = AvatarManager.shared.cachedAvatar(for: recipient.avatarPath) ?? UIImage(named: "avatar-placeholder")
            title = recipient.nameOrDisplayName
        }

        if let message = thread.messages.last, let messageBody = message.body {
            switch SofaType(sofa: messageBody) {
            case .message:
                subtitle = SofaMessage(content: messageBody).body
            case .paymentRequest:
                subtitle = SofaPaymentRequest(content: messageBody).body
            default:
                break
            }
        }

        let date = self.thread.lastMessageDate()

        if DateTimeFormatter.isDate(date, sameDayAs: Date()) {
            details = DateTimeFormatter.timeFormatter.string(from: date)
        } else {
            details = DateTimeFormatter.dateFormatter.string(from: date)
        }

        return TableCellData(title: title, subtitle: subtitle, leftImage: avatar, details: details, badgeText: badgeText)
    }()

    private func recipient(for thread: TSThread) -> TokenUser? {
        guard let recipientAddress = thread.contactIdentifier() else { return nil }

        var recipient: TokenUser?

        let retrievedData = contactOrNonContactData(for: recipientAddress)

        if let userData = retrievedData,
            let deserialised = (try? JSONSerialization.jsonObject(with: userData, options: [])),
            let json = deserialised as? [String: Any] {

            recipient = TokenUser(json: json, shouldSave: false)
        } else if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            recipient = appDelegate.contactsManager.tokenContacts.first(where: { $0.address == recipientAddress })
        }

        return recipient
    }

    private func contactOrNonContactData(for address: String) -> Data? {
        return (Yap.sharedInstance.retrieveObject(for: address, in: ThreadsDataSource.nonContactsCollectionKey) as? Data) ?? (Yap.sharedInstance.retrieveObject(for: address, in: TokenUser.favoritesCollectionKey) as? Data)
    }
}
