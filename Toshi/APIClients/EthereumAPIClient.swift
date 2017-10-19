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
import Teapot
import AwesomeCache

public typealias BalanceCompletion = ((_ balance: NSDecimalNumber, _ error: Error?) -> Void)

public class EthereumAPIClient: NSObject {

    @objc static let shared: EthereumAPIClient = EthereumAPIClient()

    fileprivate var mainTeapot: Teapot

    fileprivate var switchedNetworkTeapot: Teapot

    fileprivate var activeTeapot: Teapot {
        if NetworkSwitcher.shared.isDefaultNetworkActive {
            return mainTeapot
        } else {
            return switchedNetworkTeapot
        }
    }

    fileprivate static var teapotUrl: String {
        return NetworkSwitcher.shared.activeNetworkBaseUrl
    }

    fileprivate static let CachedBalanceKey = "CachedBalanceKey"
    fileprivate lazy var cache: Cache<NSDecimalNumber> = {
        do {
            return try Cache<NSDecimalNumber>(name: "balanceCache")
        } catch {
            fatalError("Couldn't instantiate the balance cache")
        }
    }()

    convenience init(mockTeapot: MockTeapot) {
        self.init()
        self.switchedNetworkTeapot = mockTeapot
        self.mainTeapot = mockTeapot
    }

    fileprivate override init() {
        mainTeapot = Teapot(baseURL: URL(string: NetworkSwitcher.shared.defaultNetworkBaseUrl)!)
        switchedNetworkTeapot = Teapot(baseURL: URL(string: NetworkSwitcher.shared.defaultNetworkBaseUrl)!)

        super.init()
    }

    public func createUnsignedTransaction(parameters: [String: Any], completion: @escaping ((_ unsignedTransaction: String?, _ error: Error?) -> Void)) {
        let json = RequestParameter(parameters)

        self.activeTeapot.post("/v1/tx/skel", parameters: json) { result in
            var resultString: String?
            var resultError: Error?

            switch result {
            case .success(let json, _):
                resultString = json?.dictionary!["tx"] as? String
            case .failure(_, _, let error):
                resultError = error
                print(error)
            }

            DispatchQueue.main.async {
                completion(resultString, resultError)
            }
        }
    }

    public func sendSignedTransaction(originalTransaction: String, transactionSignature: String, completion: @escaping ((_ success: Bool, _ json: RequestParameter?, _ message: String?) -> Void)) {
        timestamp(activeTeapot) { timestamp, error in
            guard let timestamp = timestamp else {
                completion(false, nil, error?.localizedDescription ?? "error fetching timestamp")
                return
            }

            let cereal = Cereal.shared
            let path = "/v1/tx"
            let params = [
                "tx": originalTransaction,
                "signature": transactionSignature
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: params, options: []), let payloadString = String(data: data, encoding: .utf8) else {
                print("Invalid payload, request could not be executed")
                completion(false, nil, "Invalid payload, request could not be executed")
                return
            }

            guard let paymentAddress = Cereal.shared.paymentAddress else { fatalError("No cereal address when requested") }

            let hashedPayload = cereal.sha3WithWallet(string: payloadString)
            let signature = "0x\(cereal.signWithWallet(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

            let headers: [String: String] = [
                "Token-ID-Address": paymentAddress,
                "Token-Signature": signature,
                "Token-Timestamp": timestamp
            ]

            let json = RequestParameter(params)

            self.activeTeapot.post(path, parameters: json, headerFields: headers) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let json, _):
                        completion(true, json, nil)
                    case .failure(let json, _, let error):
                        guard let jsonError = (json?.dictionary?["errors"] as? [[String: Any]])?.first else {
                            completion(false, nil, error.localizedDescription)
                            return
                        }

                        completion(false, nil, jsonError["message"] as? String)
                    }
                }
            }
        }
    }

    public func getBalance(address: String = Cereal.shared.paymentAddress!, cachedBalanceCompletion: @escaping BalanceCompletion = { balance, _ in }, fetchedBalanceCompletion: @escaping BalanceCompletion) {

        let cachedBalance: NSDecimalNumber = self.cache.object(forKey: EthereumAPIClient.CachedBalanceKey) ?? .zero
        cachedBalanceCompletion(cachedBalance, nil)

        self.activeTeapot.get("/v1/balance/\(address)") { [weak self] (result: NetworkResult) in
            var balance: NSDecimalNumber = .zero
            var resultError: Error?

            switch result {
            case .success(let json, let response):
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedFailureReasonErrorKey: "Could not fetch balance."])
                guard response.statusCode == 200 else { fetchedBalanceCompletion(0, error); return }
                guard let json = json?.dictionary else { fetchedBalanceCompletion(0, error); return }

                let unconfirmedBalanceString = json["unconfirmed_balance"] as? String ?? "0"
                let unconfirmedBalance = NSDecimalNumber(hexadecimalString: unconfirmedBalanceString)

                TokenUser.current?.balance = unconfirmedBalance
                balance = unconfirmedBalance

            case .failure(_, _, let error):
                resultError = error
                print(error)
            }

            DispatchQueue.main.async {
                self?.cache.setObject(balance, forKey: EthereumAPIClient.CachedBalanceKey)
                fetchedBalanceCompletion(balance, resultError)
            }
        }
    }

    @objc public func registerForMainNetworkPushNotifications() {
        timestamp(mainTeapot) { timestamp, _ in
            guard let timestamp = timestamp else { return }
            self.registerForPushNotifications(timestamp, teapot: self.mainTeapot) { _, _ in }
        }
    }

    @objc public func registerForSwitchedNetworkPushNotificationsIfNeeded(completion: ((_ success: Bool, _ message: String?) -> Void)? = nil) {
        guard NetworkSwitcher.shared.isDefaultNetworkActive == false else {
            completion?(true, nil)
            return
        }

        switchedNetworkTeapot.baseURL = URL(string: NetworkSwitcher.shared.activeNetworkBaseUrl)!

        timestamp(switchedNetworkTeapot) { timestamp, _ in
            guard let timestamp = timestamp else { return }
            self.registerForPushNotifications(timestamp, teapot: self.switchedNetworkTeapot, completion: completion)
        }
    }

    @objc public func deregisterFromMainNetworkPushNotifications(completion: @escaping ((_ success: Bool, _ message: String?) -> Void) = { (Bool, String) in }) {
        timestamp(mainTeapot) { timestamp, _ in
            guard let timestamp = timestamp else { return }
            self.deregisterFromPushNotifications(timestamp, teapot: self.mainTeapot, completion: completion)
        }
    }

    public func deregisterFromSwitchedNetworkPushNotifications(completion: @escaping ((_ success: Bool, _ message: String?) -> Void) = { (Bool, String) in }) {

        timestamp(switchedNetworkTeapot) { timestamp, _ in
            guard let timestamp = timestamp else { return }
            self.deregisterFromPushNotifications(timestamp, teapot: self.switchedNetworkTeapot, completion: completion)
        }
    }

    fileprivate func timestamp(_ teapot: Teapot, _ completion: @escaping ((_ timestamp: String?, _ error: Error?) -> Void)) {
        teapot.get("/v1/timestamp") { (result: NetworkResult) in
            switch result {
            case .success(let json, _):
                guard let json = json?.dictionary else { fatalError() }
                guard let timestamp = json["timestamp"] as? Int else { fatalError("Timestamp should be an integer") }

                completion(String(timestamp), nil)
            case .failure(_, _, let error):
                completion(nil, error)
                print(error)
            }
        }
    }

    fileprivate func registerForPushNotifications(_ timestamp: String, teapot: Teapot, completion: ((_ success: Bool, _ message: String?) -> Void)? = nil) {
        
        let cereal = Cereal.shared
        let path = "/v1/apn/register"
        guard let address = Cereal.shared.address else { fatalError("No cereal address when requested") }
        let params = ["registration_id": ChatService.shared.token, "address": cereal.paymentAddress]

        guard let data = try? JSONSerialization.data(withJSONObject: params, options: []), let payloadString = String(data: data, encoding: .utf8) else {
            DispatchQueue.main.async {
                completion?(false, "Invalid payload, request could not be executed")
            }
            
            return
        }

        let hashedPayload = cereal.sha3WithID(string: payloadString)
        let signature = "0x\(cereal.signWithID(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

        let headerFields: [String: String] = [
            "Token-ID-Address": address,
            "Token-Signature": signature,
            "Token-Timestamp": timestamp
        ]

        let json = RequestParameter(params)
        var success = false
        var resultString = ""

        teapot.post(path, parameters: json, headerFields: headerFields) { result in
            switch result {
            case .success(let json, let response):
                print("\n +++ Registered for :\(teapot.baseURL)")
                success = true
                resultString = "json: \(json?.dictionary ?? [String: Any]()) response: \(response)"
            case .failure(let json, let response, let error):
                print(error)
                resultString = "json: \(json?.dictionary ?? [String: Any]()) response: \(response), error: \(error)"
            }

            DispatchQueue.main.async {
                completion?(success, resultString)
            }
        }
    }

    fileprivate func deregisterFromPushNotifications(_ timestamp: String, teapot: Teapot, completion: @escaping ((_ success: Bool, _ message: String?) -> Void) = { (Bool, String) in }) {

        let cereal = Cereal.shared
        guard let address = Cereal.shared.paymentAddress else { fatalError("No cereal address when requested") }
        let path = "/v1/apn/deregister"

        let params = ["registration_id": ChatService.shared.token, "address": cereal.paymentAddress]

        guard let data = try? JSONSerialization.data(withJSONObject: params, options: []), let payloadString = String(data: data, encoding: .utf8) else {
            completion(false, "Invalid payload, request could not be executed")
            return
        }

        let hashedPayload = cereal.sha3WithWallet(string: payloadString)
        let signature = "0x\(cereal.signWithWallet(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

        let headerFields: [String: String] = [
            "Token-ID-Address": address,
            "Token-Signature": signature,
            "Token-Timestamp": timestamp
        ]

        let json = RequestParameter(params)

        var success = false
        var resultString = ""

        teapot.post(path, parameters: json, headerFields: headerFields) { result in
            switch result {
            case .success(let json, let response):
                print("\n --- DE-registered from :\(teapot.baseURL)")
                success = true
                resultString = "json:\(json?.dictionary ?? [String: Any]()), response: \(response)"
            case .failure(let json, let response, let error):
                print(error)
                resultString = "json:\(json?.dictionary ?? [String: Any]()), response: \(response), error: \(error)"
            }

            DispatchQueue.main.async {
                completion(success, resultString)
            }
        }
    }
}
