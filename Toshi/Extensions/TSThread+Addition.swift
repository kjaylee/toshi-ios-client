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

extension TSThread {
    func recipient() -> TokenUser? {
        guard let recipientAddress = contactIdentifier() else { return nil }

        var recipient: TokenUser?

        if let userData = (Yap.sharedInstance.retrieveObject(for: recipientAddress, in: ThreadsDataSource.nonContactsCollectionKey) as? Data),
            let deserialised = (try? JSONSerialization.jsonObject(with: userData, options: [])),
            let json = deserialised as? [String: Any] {

            recipient = TokenUser(json: json, shouldSave: false)
        }

        return recipient
    }
}
