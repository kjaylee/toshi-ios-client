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
import WebKit

final class SOFAWebController: UIViewController {

    enum Method: String {
        case getAccounts
        case signTransaction
        case signMessage
        case signPersonalMessage
        case publishTransaction
        case approveTransaction
    }

    private var etherAPIClient: EthereumAPIClient {
        return EthereumAPIClient.shared
    }

    private let rcpUrl = ToshiWebviewRPCURLPath
    
    private lazy var webViewConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        
        var js = "window.SOFA = {config: {rcpUrl: '" + self.rcpUrl + "'}}; "
        
        if let filepath = Bundle.main.path(forResource: "sofa-web3", ofType: "js") {
            do {
                js += try String(contentsOfFile: filepath)
                DLog("Loaded sofa.js")
            } catch {
                DLog("Failed to load sofa.js")
            }
        } else {
            DLog("Sofa.js not found in bundle")
        }
        
        var userScript: WKUserScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        
        configuration.userContentController.add(self, name: Method.getAccounts.rawValue)
        configuration.userContentController.add(self, name: Method.signPersonalMessage.rawValue)
        configuration.userContentController.add(self, name: Method.signMessage.rawValue)
        configuration.userContentController.add(self, name: Method.signTransaction.rawValue)
        configuration.userContentController.add(self, name: Method.publishTransaction.rawValue)
        configuration.userContentController.add(self, name: Method.approveTransaction.rawValue)
        
        configuration.userContentController.addUserScript(userScript)

        return configuration
    }()

    private lazy var webView: WKWebView = {
        let view = WKWebView(frame: self.view.frame, configuration: self.webViewConfiguration)
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.isScrollEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.navigationDelegate = self

        return view
    }()

    private lazy var backButton: UIButton = {
        let view = UIButton(type: .custom)
        view.bounds.size = CGSize(width: 44, height: 44)
        view.setImage(#imageLiteral(resourceName: "web_back").withRenderingMode(.alwaysTemplate), for: .normal)
        view.addTarget(self, action: #selector(self.didTapBackButton), for: .touchUpInside)

        return view
    }()

    private lazy var forwardButton: UIButton = {
        let view = UIButton(type: .custom)
        view.bounds.size = CGSize(width: 44, height: 44)
        view.setImage(#imageLiteral(resourceName: "web_forward").withRenderingMode(.alwaysTemplate), for: .normal)
        view.addTarget(self, action: #selector(self.didTapForwardButton), for: .touchUpInside)

        return view
    }()

    private lazy var backBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(customView: self.backButton)
    }()

    private lazy var forwardBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(customView: self.forwardButton)
    }()

    private lazy var toolbar: UIToolbar = {
        let view = UIToolbar(withAutoLayout: true)

        let share = UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil)
        let spacing = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let placeholder = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        placeholder.width = 44

        view.items = [self.backBarButtonItem, spacing, self.forwardBarButtonItem, spacing, share, spacing, placeholder]

        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(webView)
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            self.toolbar.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.toolbar.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            self.toolbar.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        toolbar.set(height: 44)
        hidesBottomBarWhenPushed = true
        webView.fillSuperview()
    }

    func load(url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
    }

    init() {
        super.init(nibName: nil, bundle: nil)

        loadViewIfNeeded()
    }

    required init?(coder _: NSCoder) {
        fatalError()
    }

    @objc
    private func didTapBackButton() {
        webView.goBack()
    }

    @objc
    private func didTapForwardButton() {
        webView.goForward()
    }
}

extension SOFAWebController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        backBarButtonItem.isEnabled = webView.canGoBack
        forwardBarButtonItem.isEnabled = webView.canGoForward
    }
}

extension SOFAWebController: WKScriptMessageHandler {
    private func jsCallback(callbackId: String, payload: String) {
        let js = "SOFA.callback(\"" + callbackId + "\",\"" + payload + "\")"

        webView.evaluateJavaScript("javascript:" + js) { jsReturnValue, error in
            if let error = error {
                DLog("Error: \(error)")
            } else if let newCount = jsReturnValue as? Int {
                DLog("Returned value: \(newCount)")
            } else {
                DLog("No return from JS")
            }
        }
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let method = Method(rawValue: message.name) else { return DLog("failed \(message.name)") }
        guard let callbackId = (message.body as? NSDictionary)?.value(forKey: "callback") as? String else { return DLog("missing callback id") }

        switch method {
        case .getAccounts:
            let payload = "{\\\"error\\\": null, \\\"result\\\": [\\\"" + Cereal.shared.paymentAddress + "\\\"]}"
            jsCallback(callbackId: callbackId, payload: payload)
        case .signPersonalMessage:
            guard let messageBody = message.body as? [String: Any], let msgParams = messageBody["msgParams"] as? [String: Any], let messageEncodedString = msgParams["data"] as? String else {
                jsCallback(callbackId: callbackId, payload: "{\\\"error\\\": \\\"Invalid Message Body\\\"}")
                return
            }

            if let messageData = messageEncodedString.hexadecimalData, let decodedString = String(data: messageData, encoding: .utf8) {

                DispatchQueue.main.async {
                    self.presentPersonalMessageSignAlert(decodedString, callbackId: callbackId, signHandler: { [weak self] returnedCallbackId in
                        let composedString = "\u{0019}Ethereum Signed Message:\n" + String(messageData.count) + decodedString

                        if let resultData = composedString.data(using: .utf8) {
                            var signature = "0x\(Cereal.shared.signWithWallet(hex: resultData.hexEncodedString()))"

                            let index = signature.index(signature.startIndex, offsetBy: 130)
                            if let suffix = Int(signature.suffix(from: index)) {
                                let resultSuffix = suffix + 27

                                let truncated = signature.dropLast(2)
                                let suffixHex = String(format: "%2X", resultSuffix)

                                signature = truncated + suffixHex
                                self?.jsCallback(callbackId: returnedCallbackId, payload: "{\\\"result\\\":\\\"\(signature)\\\"}")
                            }
                        }
                    })
                }
            } else {
                jsCallback(callbackId: callbackId, payload: "{\\\"error\\\": \\\"Invalid Message Body\\\"}")
            }

        case .signMessage:
            guard let messageBody = message.body as? [String: Any], let msgParams = messageBody["msgParams"] as? [String: Any], let messageEncodedString = msgParams["data"] as? String, messageEncodedString.isValidSha3Hash else {
                jsCallback(callbackId: callbackId, payload: "{\\\"error\\\": \\\"Invalid Message Body\\\"}")
                return
            }

            DispatchQueue.main.async {
                self.presentPersonalMessageSignAlert("\(Localized("eth_sign_warning"))\n\n\(messageEncodedString)", callbackId: callbackId, signHandler: { [weak self] returnedCallbackId in

                    var signature = "0x\(Cereal.shared.signWithWallet(hash: messageEncodedString))"

                    let index = signature.index(signature.startIndex, offsetBy: 130)
                    if let suffix = Int(signature.suffix(from: index)) {
                        let resultSuffix = suffix + 27

                        let truncated = signature.dropLast(2)
                        let suffixHex = String(format: "%2X", resultSuffix)

                        signature = truncated + suffixHex
                        self?.jsCallback(callbackId: returnedCallbackId, payload: "{\\\"result\\\":\\\"\(signature)\\\"}")
                    }
                })
            }

        case .signTransaction:
            guard let messageBody = message.body as? [String: Any], let transaction = messageBody["tx"] as? [String: Any] else {
                jsCallback(callbackId: callbackId, payload: "{\\\"error\\\": \\\"Invalid Message Body\\\"}")
                return
            }

            var parameters: [String: Any] = [:]
            if let from = transaction["from"] {
                parameters["from"] = from
            }
            if let to = transaction["to"] {
                parameters["to"] = to
            }
            if let value = transaction["value"] {
                parameters["value"] = value
            } else {
                parameters["value"] = "0x0"
            }
            if let data = transaction["data"] {
                parameters["data"] = data
            }
            if let gas = transaction["gas"] {
                parameters["gas"] = gas
            }
            if let gasPrice = transaction["gasPrice"] {
                parameters["gasPrice"] = gasPrice
            }
            if let nonce = transaction["nonce"] {
                parameters["nonce"] = nonce
            }

            if let to = transaction["to"] as? String, let value = parameters["value"] as? String {
                IDAPIClient.shared.retrieveUser(username: to) { [weak self] user in
                    var userInfo = UserInfo(address: to, paymentAddress: to, avatarPath: nil, name: nil, username: to, isLocal: false)
                    if let user = user {
                        userInfo.avatarPath = user.avatarPath
                        userInfo.username = user.username
                        userInfo.name = user.name
                        userInfo.isLocal = true
                    }

                    let decimalValue = NSDecimalNumber(hexadecimalString: value)
                    let fiatValueString = EthereumConverter.fiatValueString(forWei: decimalValue, exchangeRate: ExchangeRateClient.exchangeRate)
                    let ethValueString = EthereumConverter.ethereumValueString(forWei: decimalValue)
                    let messageText = String(format: Localized("payment_confirmation_warning_message"), fiatValueString, ethValueString, user?.name ?? to)

                    self?.presentPaymentConfirmation(with: messageText, parameters: parameters, userInfo: userInfo, callbackId: callbackId)
                }
            }
        case .publishTransaction:
            guard let messageBody = message.body as? [String: Any],
                  let signedTransaction = messageBody["rawTx"] as? String else {
                jsCallback(callbackId: callbackId, payload: "{\\\"error\\\": \\\"Invalid Message Body\\\"}")
                return
            }

            self.sendSignedTransaction(signedTransaction, with: callbackId, completion: { [weak self] returnedCallbackId, payload in
                self?.jsCallback(callbackId: returnedCallbackId, payload: payload)
            })

        case .approveTransaction:
            let payload = "{\\\"error\\\": null, \\\"result\\\": true}"
            jsCallback(callbackId: callbackId, payload: payload)
        }
    }

    private func sendSignedTransaction(_ transaction: String, with callbackId: String, completion: @escaping ((String, String) -> Void)) {

        etherAPIClient.sendSignedTransaction(signedTransaction: transaction) { success, json, error in
            guard success, let json = json?.dictionary else {
                completion(callbackId, "{\\\"error\\\": \\\"\(error?.description ?? "Error sending transaction")\\\"}")

                return
            }

            guard let txHash = json["tx_hash"] as? String else {
                completion(callbackId, "{\\\"error\\\": \\\"Error recovering transaction hash\\\"}")

                return
            }

            completion(callbackId, "{\\\"result\\\":\\\"\(txHash)\\\"}")
        }
    }

    private func presentPaymentConfirmation(with messageText: String, parameters: [String: Any], userInfo: UserInfo, callbackId: String) {

        PaymentConfirmation.shared.present(for: parameters, title: Localized("payment_request_confirmation_warning_title"), message: messageText, approveHandler: { [weak self] transaction, error in

            guard error == nil else {
                let payload = SOFAResponseConstants.skeletonErrorJSON
                self?.jsCallback(callbackId: callbackId, payload: payload)

                return
            }

            self?.approvePayment(with: parameters, userInfo: userInfo, transaction: transaction, callbackId: callbackId)
            }, cancelHandler: { [weak self] in
                let payload = "{\\\"error\\\": \\\"Transaction declined by user\\\", \\\"result\\\": null}"
                self?.jsCallback(callbackId: callbackId, payload: payload)
        })
    }

    private func approvePayment(with parameters: [String: Any], userInfo _: UserInfo, transaction: String?, callbackId: String) {

        let payload: String

        if let transaction = transaction, let encodedSignedTransaction = Cereal.shared.signEthereumTransactionWithWallet(hex: transaction) {
            payload = "{\\\"result\\\":\\\"\(encodedSignedTransaction)\\\"}"
        } else {
            payload = SOFAResponseConstants.skeletonErrorJSON
        }

        jsCallback(callbackId: callbackId, payload: payload)
    }

    private func presentPersonalMessageSignAlert(_ message: String, callbackId: String, signHandler: @escaping ((String) -> Void)) {

        let alert = UIAlertController(title: Localized("sign_alert_title"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized("cancel_action_title"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localized("sign_action_title"), style: .default, handler: { _ in
            signHandler(callbackId)
        }))

        Navigator.presentModally(alert)
    }
}

struct SOFAResponseConstants {
    static let skeletonErrorJSON = "{\\\"error\\\": \\\"Error constructing tx skeleton\\\", \\\"result\\\": null}"
}

extension SOFAWebController: PaymentPresentable {
    func paymentApproved(with parameters: [String: Any], userInfo _: UserInfo) {
        //we do not use this currently
    }

    func paymentDeclined() {
        //we dnt use this currently
    }
}
