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
import SweetUIKit
import CoreImage
import TinyConstraints

class ProfileViewController: UIViewController {

    private lazy var activityView: UIActivityIndicatorView = {
        self.defaultActivityIndicator()
    }()

    var profile: TokenUser

    private var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    private var messageSender: MessageSender? {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate

        return appDelegate?.messageSender
    }

    private var profileView: ProfileView? { return view as? ProfileView }

    init(profile: TokenUser) {
        self.profile = profile

        super.init(nibName: nil, bundle: nil)

        if #available(iOS 11.0, *) {
            edgesForExtendedLayout = .all
        } else {
            edgesForExtendedLayout = .bottom
        }

        title = "Contact"
    }

    required init?(coder _: NSCoder) {
        fatalError("The method `init?(coder)` is not implemented for this class.")
    }

    override func loadView() {
        if profile.isCurrentUser {
            view = ProfileView(viewType: .personalProfileReadOnly)
        } else {
            view = ProfileView(viewType: .profile)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupActivityIndicator()

        profileView?.profileDelegate = self

        if !profile.isCurrentUser {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "more"), style: .plain, target: self, action: #selector(didSelectMoreButton))
        }

        view.backgroundColor = Theme.lightGrayBackgroundColor

        updateReputation()

        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseDidChange(notification:)), name: .YapDatabaseModified, object: nil)
    }

    private lazy var uiDatabaseConnection: YapDatabaseConnection = {
        let database = Yap.sharedInstance.database!
        let dbConnection = database.newConnection()
        dbConnection.beginLongLivedReadTransaction()

        return dbConnection
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        preferLargeTitleIfPossible(false)

        profileView?.setProfile(profile)

        AvatarManager.shared.avatar(for: profile.avatarPath) { [weak self] image, _ in
            if image != nil {
                self?.profileView?.avatarImageView.image = image
            }
        }

        updateButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        preferLargeTitleIfPossible(true)
    }

    @objc
    private func yapDatabaseDidChange(notification _: NSNotification) {
        let notifications = uiDatabaseConnection.beginLongLivedReadTransaction()

        if uiDatabaseConnection.hasChange(forKey: profile.address, inCollection: TokenUser.favoritesCollectionKey, in: notifications) {
            updateButton()
        }
    }
    
    private func updateButton() {
        uiDatabaseConnection.read { [weak self] transaction in
            guard let strongSelf = self else { return }

            let isProfileAdded = transaction.object(forKey: strongSelf.profile.address, inCollection: TokenUser.favoritesCollectionKey) != nil

            let fontColor = isProfileAdded ? Theme.tintColor : Theme.lightGreyTextColor
            let title = isProfileAdded ? "Favorited" : "Favorite"

            strongSelf.profileView?.actionView.addFavoriteButton.titleLabel.text = title
            strongSelf.profileView?.actionView.addFavoriteButton.tintColor = fontColor
        }
    }

    private func presentUserRatingPrompt(profile: TokenUser) {
        let rateUserController = RateUserController(user: profile)
        rateUserController.delegate = self

        Navigator.presentModally(rateUserController)
    }

    @objc private func didSelectMoreButton() {
        let actions = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let address = profile.address

        if profile.isBlocked {
            let unblockAction = UIAlertAction(title: Localized("unblock_action_title"), style: .destructive) { _ in
                OWSBlockingManager.shared().removeBlockedPhoneNumber(address)

                let alert = UIAlertController.dismissableAlert(title: Localized("unblock_user_title"), message: Localized("unblock_user_message"))
                Navigator.presentModally(alert)
            }

            actions.addAction(unblockAction)
        } else {
            let blockUserAction = UIAlertAction(title: Localized("block_action_title"), style: .destructive) { _ in
                self.didSelectBlockUser()
            }

            actions.addAction(blockUserAction)
        }

        let reportAction = UIAlertAction(title: Localized("report_action_title"), style: .destructive) { _ in
            self.idAPIClient.reportUser(address: address) { success, error in
                self.showReportUserFeedbackAlert(success, message: error?.description)
            }
        }

        actions.addAction(reportAction)
        actions.addAction(UIAlertAction(title: Localized("cancel_action_title"), style: .cancel))

        Navigator.presentModally(actions)
    }

    private func showReportUserFeedbackAlert(_ success: Bool, message: String?) {
        guard success else {
            let alert = UIAlertController.dismissableAlert(title: Localized("error_title"), message: message)
            Navigator.presentModally(alert)

            return
        }

        let alert = UIAlertController.dismissableAlert(title: Localized("report_feedback_alert_title"), message: Localized("report_feedback_alert_message"))
        Navigator.presentModally(alert)
    }

    private func didSelectBlockUser() {
        let alert = UIAlertController(title: Localized("block_alert_title"), message: Localized("block_alert_message"), preferredStyle: .alert)
        let blockAction = UIAlertAction(title: Localized("block_action_title"), style: .default) { _ in
            OWSBlockingManager.shared().addBlockedPhoneNumber(self.profile.address)

            let alert = UIAlertController.dismissableAlert(title: Localized("block_feedback_alert_title"), message: Localized("block_feedback_alert_message"))
            Navigator.presentModally(alert)
        }

        alert.addAction(blockAction)
        alert.addAction(UIAlertAction(title: Localized("cancel_action_title"), style: .cancel))

        Navigator.presentModally(alert)
    }

    private func updateReputation() {
        RatingsClient.shared.scores(for: profile.address) { [weak self] ratingScore in
            self?.profileView?.reputationView.setScore(ratingScore)
        }
    }
}

extension ProfileViewController: ActivityIndicating {
    var activityIndicator: UIActivityIndicatorView {
        return activityView
    }
}

extension ProfileViewController: RateUserControllerDelegate {
    func didRate(_ user: TokenUser, rating: Int, review: String) {
        dismiss(animated: true) {
            RatingsClient.shared.submit(userId: user.address, rating: rating, review: review) { [weak self] success, error in
                guard success == true else {
                    let alert = UIAlertController(title: Localized("error_title"), message: error?.description, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))

                    Navigator.presentModally(alert)
                    return
                }

                self?.updateReputation()
            }
        }
    }
}

extension ProfileViewController: PaymentControllerDelegate {

    func paymentControllerFinished(with valueInWei: NSDecimalNumber?, for controller: PaymentController) {
        
        defer { dismiss(animated: true) }
        guard let value = valueInWei else { return }

        let parameters: [String: Any] = [
            "from": Cereal.shared.paymentAddress,
            "to": self.profile.paymentAddress,
            "value": value.toHexString
        ]

        showActivityIndicator()

        let fiatValueString = EthereumConverter.fiatValueString(forWei: value, exchangeRate: ExchangeRateClient.exchangeRate)
        let ethValueString = EthereumConverter.ethereumValueString(forWei: value)
        let messageText = String(format: Localized("payment_confirmation_warning_message"), fiatValueString, ethValueString, self.profile.name)

        PaymentConfirmation.shared.present(for: parameters, title: Localized("payment_request_confirmation_warning_title"), message: messageText, presentCompletionHandler: { [weak self] in
            self?.hideActivityIndicator()
            }, approveHandler: { [weak self] transaction, error in

                guard error == nil else { return }
                
                self?.sendPayment(with: parameters, transaction: transaction)
        })
    }

    private func sendPayment(with parameters: [String: Any], transaction: String?) {
        showActivityIndicator()

        let etherAPIClient = EthereumAPIClient.shared

        guard let transaction = transaction else {
            self.hideActivityIndicator()

            return
        }

        let signedTransaction = "0x\(Cereal.shared.signWithWallet(hex: transaction))"

        etherAPIClient.sendSignedTransaction(originalTransaction: transaction, transactionSignature: signedTransaction) { [weak self] success, json, error in
            guard let strongSelf = self else { return }

            strongSelf.hideActivityIndicator()

            guard success else {
                let alert = UIAlertController.dismissableAlert(title: Localized("payment_error_message"), message: error?.description ?? ToshiError.genericError.description)
                Navigator.presentModally(alert)
                return
            }

            if let json = json?.dictionary, let value = parameters["value"] as? String {
                guard let txHash = json["tx_hash"] as? String else {
                    CrashlyticsLogger.log("Error recovering transaction hash.")
                    fatalError("Error recovering transaction hash.") }
                let payment = SofaPayment(txHash: txHash, valueHex: value)

                // send message to thread
                let thread = ChatInteractor.getOrCreateThread(for: strongSelf.profile.address)
                let timestamp = NSDate.ows_millisecondsSince1970(for: Date())
                let outgoingMessage = TSOutgoingMessage(timestamp: timestamp, in: thread, messageBody: payment.content)

                strongSelf.messageSender?.send(outgoingMessage, success: {
                    DLog("message sent")
                }, failure: { error in
                    DLog("\(error)")
                    if error.localizedDescription == "ERROR_DESCRIPTION_UNREGISTERED_RECIPIENT" {
                        CrashlyticsLogger.nonFatal("Could not send payment because recipient was unregistered", error: (error as NSError), attributes: nil)
                    } else {
                        CrashlyticsLogger.log("Can not send message", attributes: [.error: error.localizedDescription])
                    }
                })
            }
        }
    }
}

extension ProfileViewController: ProfileViewDelegate {
    func didTapMessageProfileButton(in view: ProfileView) {
        // create thread if needed
        ChatInteractor.getOrCreateThread(for: profile.address)

        DispatchQueue.main.async {
            (self.tabBarController as? TabBarController)?.displayMessage(forAddress: self.profile.address)

            if let navController = self.navigationController as? BrowseNavigationController {
                _ = navController.popToRootViewController(animated: false)
            }
        }
    }

    func didTapAddProfileButton(in view: ProfileView) {
        if Yap.sharedInstance.containsObject(for: profile.address, in: TokenUser.favoritesCollectionKey) {
            Yap.sharedInstance.removeObject(for: profile.address, in: TokenUser.favoritesCollectionKey)
        } else {
            Yap.sharedInstance.insert(object: profile.json, for: profile.address, in: TokenUser.favoritesCollectionKey)
            SoundPlayer.playSound(type: .addedProfile)
        }
    }

    func didTapPayButton(in view: ProfileView) {
        let paymentController = PaymentController(withPaymentType: .send, continueOption: .send)
        paymentController.delegate = self

        let navigationController = UINavigationController(rootViewController: paymentController)
        Navigator.presentModally(navigationController)
    }

    func didTapRateUser(in view: ProfileView) {
        presentUserRatingPrompt(profile: profile)
    }
}
