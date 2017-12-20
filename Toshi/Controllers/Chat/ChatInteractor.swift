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

protocol ChatInteractorOutput: class {
    func didCatchError(_ message: String)

    func didFinishRequest()
}

final class ChatInteractor: NSObject {

    private weak var output: ChatInteractorOutput?
    private(set) var thread: TSThread

    init(output: ChatInteractorOutput?, thread: TSThread) {
        self.output = output
        self.thread = thread

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        self.messageSender = appDelegate.messageSender
    }

    private var etherAPIClient: EthereumAPIClient {
        return EthereumAPIClient.shared
    }

    private var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    private var messageSender: MessageSender?

    func sendMessage(sofaWrapper: SofaWrapper, date: Date = Date(), completion: @escaping ((Bool) -> Void) = { Bool in }) {
        let timestamp = NSDate.ows_millisecondTimeStamp()

        sofaWrapper.removeFiatValueString()
        let outgoingMessage = TSOutgoingMessage(timestamp: timestamp, in: self.thread, messageBody: sofaWrapper.content)

        self.send(outgoingMessage, completion: completion)
    }

    func send(_ signalMessage: TSOutgoingMessage, completion: @escaping ((Bool) -> Void) = { Bool in }) {
        DispatchQueue.main.async {
            self.messageSender?.send(signalMessage, success: {
                completion(true)
                DLog("message sent")
            }, failure: { error in
                completion(false)
                DLog("\(error)")
            })
        }
    }

    func send(image: UIImage, in message: TSOutgoingMessage? = nil, completion: ((Bool) -> Void)? = nil) {
        guard let imageData = UIImagePNGRepresentation(image) else { return }

        let wrapper = SofaMessage(body: "")
        let timestamp = NSDate.ows_millisecondsSince1970(for: Date())
        let outgoingMessage = message ?? TSOutgoingMessage(timestamp: timestamp, in: thread, messageBody: wrapper.content)

        guard let datasource = DataSourceValue.dataSource(with: imageData, fileExtension: "png") else { return }

        messageSender?.sendAttachmentData(datasource, contentType: "image/jpeg", sourceFilename: "image.jpeg", in: outgoingMessage, success: {
            DLog("Success")
            DispatchQueue.main.async {
                completion?(true)
            }
        }, failure: { error in
            DLog("Failure: \(error)")

            DispatchQueue.main.async {
                completion?(false)
            }
        })
    }

    func sendVideo(with url: URL) {
        guard let videoData = try? Data(contentsOf: url) else { return }

        let wrapper = SofaMessage(body: "")
        let timestamp = NSDate.ows_millisecondsSince1970(for: Date())
        let outgoingMessage = TSOutgoingMessage(timestamp: timestamp, in: thread, messageBody: wrapper.content)

        guard let datasource = DataSourceValue.dataSource(with: videoData, fileExtension: "mov") else { return }

        messageSender?.sendAttachmentData(datasource, contentType: "video/mp4", sourceFilename: "video.mp4", in: outgoingMessage, success: {
            self.output?.didFinishRequest()
            DLog("Success")
        }, failure: { error in
            self.output?.didFinishRequest()
            DLog("Failure: \(error)")
        })
    }

    func sendPayment(in value: NSDecimalNumber?, completion: ((Bool) -> Void)? = nil) {
        guard let value = value else {
            return
        }

        guard let tokenId = self.thread.contactIdentifier() else {
            return
        }

        idAPIClient.retrieveUser(username: tokenId) { [weak self] user in
            guard let user = user else { return }

            let parameters: [String: Any] = [
                "from": Cereal.shared.paymentAddress,
                "to": user.paymentAddress,
                "value": value.toHexString
            ]

            let fiatValueString = EthereumConverter.fiatValueString(forWei: value, exchangeRate: ExchangeRateClient.exchangeRate)
            let ethValueString = EthereumConverter.ethereumValueString(forWei: value)
            let messageText = String(format: Localized("payment_confirmation_warning_message"), fiatValueString, ethValueString, user.name)

            PaymentConfirmation.shared.present(for: parameters, title: Localized("payment_request_confirmation_warning_title"), message: messageText, approveHandler: { [weak self] transaction, _ in

                self?.output?.didFinishRequest()

                guard let transaction = transaction else { return }

                self?.sendPayment(with: parameters, transaction: transaction, completion: completion)
                }, cancelHandler: { [weak self] in
                    self?.output?.didFinishRequest()
            })
        }
    }

    func fetchAndUpdateBalance(cachedCompletion: @escaping BalanceCompletion, fetchedCompletion: @escaping BalanceCompletion) {
        etherAPIClient.getBalance(cachedBalanceCompletion: { cachedBalance, _ in
            cachedCompletion(cachedBalance, nil)
        }, fetchedBalanceCompletion: { fetchedBalance, error in
            fetchedCompletion(fetchedBalance, error)
        })
    }

    func sendPayment(with parameters: [String: Any], transaction: String?, completion: ((Bool) -> Void)? = nil) {

        guard let transaction = transaction else {
            self.output?.didFinishRequest()
            completion?(false)

            return
        }

        let signedTransaction = "0x\(Cereal.shared.signWithWallet(hex: transaction))"

        self.etherAPIClient.sendSignedTransaction(originalTransaction: transaction, transactionSignature: signedTransaction) { [weak self] success, json, error in

            self?.output?.didFinishRequest()

            guard success, let json = json?.dictionary else {
                DispatchQueue.main.async {
                    self?.output?.didCatchError(error?.description ?? ToshiError.genericError.description)
                    completion?(false)
                }
                return
            }

            guard let txHash = json["tx_hash"] as? String else {
                CrashlyticsLogger.log("Error recovering transaction hash.")
                fatalError("Error recovering transaction hash.")
            }
            guard let value = parameters["value"] as? String else { return }

            let payment = SofaPayment(txHash: txHash, valueHex: value)
            self?.sendMessage(sofaWrapper: payment)

            DispatchQueue.main.async {
                completion?(true)
            }
        }
    }

    func handleInvalidKeyError(_: TSInvalidIdentityKeyErrorMessage) {
    }

    /// Handle incoming interactions or previous messages when restoring a conversation.
    ///
    /// - Parameters:
    ///   - interaction: the interaction to handle. Incoming/outgoing messages, wrapping SOFA structures.
    ///   - shouldProcessCommands: If true, will process a sofa wrapper. This means replying to requests, displaying payment UI etc.
    ///

    func handleSignalMessage(_ signalMessage: TSMessage, shouldProcessCommands: Bool = false) -> Message {
        if let invalidKeyErrorMessage = signalMessage as? TSInvalidIdentityKeySendingErrorMessage {
            DispatchQueue.main.async {
                self.handleInvalidKeyError(invalidKeyErrorMessage)
            }

            return Message(sofaWrapper: nil, signalMessage: invalidKeyErrorMessage, date: invalidKeyErrorMessage.dateForSorting(), isOutgoing: false)
        }

        if shouldProcessCommands {
            let type = SofaType(sofa: signalMessage.body)
            switch type {
            case .initialRequest:
                let initialResponse = SofaInitialResponse(initialRequest: SofaInitialRequest(content: signalMessage.body ?? ""))
                sendMessage(sofaWrapper: initialResponse)
            default:
                break
            }
        }

        /// TODO: Simplify how we deal with interactions vs text messages.
        /// Since now we know we can expand the TSInteraction stored properties, maybe we can merge some of this together.
        if let interaction = signalMessage as? TSOutgoingMessage {
            let sofaWrapper = SofaWrapper.wrapper(content: interaction.body ?? "")

            if interaction.body != sofaWrapper.content {
                interaction.body = sofaWrapper.content
                interaction.save()
            }
            
            let message = Message(sofaWrapper: sofaWrapper, signalMessage: interaction, date: interaction.dateForSorting(), isOutgoing: true)

            if interaction.hasAttachments() {
                message.messageType = "Image"
            } else if let payment = SofaWrapper.wrapper(content: interaction.body ?? "") as? SofaPayment {
                message.messageType = "Actionable"
                message.attributedTitle = NSAttributedString(string: "Payment sent", attributes: [.foregroundColor: Theme.outgoingMessageTextColor, .font: Theme.medium(size: 17)])
                message.attributedSubtitle = NSAttributedString(string: EthereumConverter.balanceAttributedString(forWei: payment.value, exchangeRate: ExchangeRateClient.exchangeRate).string, attributes: [.foregroundColor: Theme.outgoingMessageTextColor, .font: Theme.regular(size: 15)])
            }

            return message
        } else if let interaction = signalMessage as? TSIncomingMessage {
            let sofaWrapper = SofaWrapper.wrapper(content: interaction.body ?? "")

            if interaction.body != sofaWrapper.content {
                interaction.body = sofaWrapper.content
                interaction.save()
            }
            
            let message = Message(sofaWrapper: sofaWrapper, signalMessage: interaction, date: interaction.dateForSorting(), isOutgoing: false, shouldProcess: shouldProcessCommands && interaction.paymentState == .none)

            if interaction.hasAttachments() {
                message.messageType = "Image"
            } else if let paymentRequest = sofaWrapper as? SofaPaymentRequest {
                message.messageType = "Actionable"
                message.title = "Payment request"
                message.attributedSubtitle = EthereumConverter.balanceAttributedString(forWei: paymentRequest.value, exchangeRate: ExchangeRateClient.exchangeRate)
            } else if let payment = sofaWrapper as? SofaPayment {
                output?.didFinishRequest()
                message.messageType = "Actionable"
                message.attributedTitle = NSAttributedString(string: "Payment received", attributes: [.foregroundColor: Theme.incomingMessageTextColor, .font: Theme.medium(size: 17)])
                message.attributedSubtitle = NSAttributedString(string: EthereumConverter.balanceAttributedString(forWei: payment.value, exchangeRate: ExchangeRateClient.exchangeRate).string, attributes: [.foregroundColor: Theme.incomingMessageTextColor, .font: Theme.regular(size: 15)])
            }

            return message
        } else {
            return Message(sofaWrapper: nil, signalMessage: signalMessage, date: signalMessage.dateForSorting(), isOutgoing: false)
        }
    }

    func playSound(for message: Message) {
        if message.isOutgoing {
            if message.sofaWrapper?.type == .paymentRequest {
                SoundPlayer.playSound(type: .requestPayment)
            } else if message.sofaWrapper?.type == .payment {
                SoundPlayer.playSound(type: .paymentSend)
            } else {
                SoundPlayer.playSound(type: .messageSent)
            }
        } else {
            SoundPlayer.playSound(type: .messageReceived)
        }
    }

    @discardableResult static func getOrCreateThread(for address: String) -> TSThread {
        var thread: TSThread?

        TSStorageManager.shared().dbReadWriteConnection?.readWrite { transaction in
            var recipient = SignalRecipient(textSecureIdentifier: address, with: transaction)

            var shouldRequestContactsRefresh = false

            if recipient == nil {
                recipient = SignalRecipient(textSecureIdentifier: address, relay: nil)
                shouldRequestContactsRefresh = true

                IDAPIClient.shared.updateContact(with: address)
            }

            recipient?.save(with: transaction)
            thread = TSContactThread.getOrCreateThread(withContactId: address, transaction: transaction)

            if shouldRequestContactsRefresh == true {
                self.requestContactsRefresh()
            }

            if thread?.archivalDate() != nil {
                thread?.unarchiveThread(with: transaction)
            }
        }

        return thread!
    }

    public static func updateGroup(with groupModel: TSGroupModel, completion: @escaping ((Bool) -> Void)) {
        var thread: TSGroupThread?
        TSStorageManager.shared().dbReadWriteConnection?.readWrite { transaction in
            thread = TSGroupThread.getOrCreateThread(with: groupModel, transaction: transaction)

            guard thread != nil else { return }
            thread!.groupModel = groupModel
            thread!.save(with: transaction)
        }

        sendGroupUpdateMessage(to: thread!, with: groupModel, completion: completion)
    }

    public static func createGroup(with recipientsIds: NSMutableArray, name: String, avatar: UIImage, completion: @escaping ((Bool) -> Void)) {

        let groupId = Randomness.generateRandomBytes(32)

        guard let groupModel = TSGroupModel(title: name, memberIds: recipientsIds, image: avatar, groupId: groupId) else { return }

        var thread: TSGroupThread?
        TSStorageManager.shared().dbReadWriteConnection?.readWrite { transaction in
            thread = TSGroupThread.getOrCreateThread(with: groupModel, transaction: transaction)
        }

        guard thread != nil else { return }

        ProfileManager.shared().addThread(toProfileWhitelist: thread!)

        Navigator.tabbarController?.openThread(thread!)

        sendInitialGroupMessage(to: thread!, completion: completion)
    }

    private static func sendGroupUpdateMessage(to thread: TSGroupThread, with groupModel: TSGroupModel, completion: @escaping ((Bool) -> Void)) {
        DispatchQueue.global(qos: .background).async {
            let timestamp = NSDate.ows_millisecondTimeStamp()
            let outgoingMessage = TSOutgoingMessage(timestamp: timestamp, in: thread, groupMetaMessage: TSGroupMetaMessage.update)
            outgoingMessage.body = "GROUP_UPDATED"

            let interactor = ChatInteractor(output: nil, thread: thread)
            interactor.send(image: groupModel.groupImage, in: outgoingMessage, completion: completion)
        }
    }

    private static func sendInitialGroupMessage(to thread: TSGroupThread, completion: @escaping ((Bool) -> Void)) {
        DispatchQueue.global(qos: .background).async {
            let timestamp = NSDate.ows_millisecondTimeStamp()
            let outgoingMessage = TSOutgoingMessage(timestamp: timestamp, in: thread, groupMetaMessage: TSGroupMetaMessage.new)
            outgoingMessage.body = "GROUP_CREATED"

            let interactor = ChatInteractor(output: nil, thread: thread)

            if let groupAvatar = thread.groupModel.groupImage {
                interactor.send(image: groupAvatar, in: outgoingMessage, completion: completion)
            } else {
                interactor.send(outgoingMessage, completion: completion)
            }
        }
    }

    static func deleteThread(_ thread: TSThread) {
        TSStorageManager.shared().dbReadWriteConnection?.asyncReadWrite { transaction in
            thread.remove(with: transaction)
            thread.markAllAsRead(with: transaction)
        }
    }

    static func sendLeaveGroupMessage(_ thread: TSGroupThread, completion: @escaping ((Bool) -> Void)) {
        DispatchQueue.global(qos: .background).async {
            let timestamp = NSDate.ows_millisecondTimeStamp()
            let outgoingMessage = TSOutgoingMessage(timestamp: timestamp, in: thread, groupMetaMessage: TSGroupMetaMessage.quit)
            outgoingMessage.body = "GROUP_CREATED"

            let interactor = ChatInteractor(output: nil, thread: thread)
            interactor.send(outgoingMessage, completion: { success in
                if success {
                    ChatInteractor.deleteThread(thread)
                    DLog("Successfully left a group")
                } else {
                    DLog("Failed to leave a group")
                }

                DispatchQueue.main.async {
                    completion(success)
                }
            })

            var newGroupMembersIds = thread.groupModel.groupMemberIds

            if let userAddressIndex = newGroupMembersIds?.index(of: Cereal.shared.address) {
                newGroupMembersIds?.remove(at: userAddressIndex)
            }

            thread.groupModel.groupMemberIds = newGroupMembersIds
            thread.save()
        }
    }

    @objc static func triggerBotGreeting() {
        guard let botAddress = Bundle.main.infoDictionary?["InitialGreetingAddress"] as? String else { return }

        let botThread = ChatInteractor.getOrCreateThread(for: botAddress)
        let interactor = ChatInteractor(output: nil, thread: botThread)

        let initialRequest = SofaInitialRequest(content: ["values": ["paymentAddress", "language"]])
        let initWrapper = SofaInitialResponse(initialRequest: initialRequest)
        interactor.sendMessage(sofaWrapper: initWrapper)
    }

    private static func requestContactsRefresh() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.contactsManager.refreshContacts()
    }
}
