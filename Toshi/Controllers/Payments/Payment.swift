import Foundation
import UIKit

let Payment = PaymentManager.shared

class PaymentManager {
    
    static let shared = PaymentManager()
    
    typealias SuccessCompletion = ((UIAlertAction) -> Void)
    
    func send(_ valueInWei: NSDecimalNumber, to paymentAddress: String, completion: @escaping SuccessCompletion) {
        
        let parameters: [String: Any] = [
            "from": Cereal.shared.paymentAddress,
            "to": paymentAddress,
            "value": valueInWei.toHexString
        ]

        let fiatValueString = EthereumConverter.fiatValueString(forWei: valueInWei, exchangeRate: ExchangeRateClient.exchangeRate)
        let ethValueString = EthereumConverter.ethereumValueString(forWei: valueInWei)
        let message = String(format: Localized("payment_confirmation_warning_message"), fiatValueString, ethValueString, paymentAddress)

        PaymentConfirmation.shared.present(for: parameters, title: Localized("payment_request_confirmation_warning_title"), message: message, approveHandler: { [weak self] transaction, _ in

            guard let transaction = transaction else { return }

            self?.send(with: parameters, transaction: transaction, completion: completion)
        })
    }

    private func send(with parameters: [String: Any], transaction: String, completion: @escaping SuccessCompletion) {

        let signedTransaction = "0x\(Cereal.shared.signWithWallet(hex: transaction))"

        EthereumAPIClient.shared.sendSignedTransaction(originalTransaction: transaction, transactionSignature: signedTransaction) { [weak self] success, _, error in

            guard success else {
                self?.showPaymentFailedMessage(for: error?.description ?? ToshiError.genericError.description)
                return
            }

            self?.showPaymentSucceededMessage(completion)
        }
    }
    
    func showPaymentFailedMessage(for errorMessage: String) {
        Navigator.presentDismissableAlert(title: Localized("payment_message_failure_title"), message: errorMessage)
    }
    
    func showPaymentSucceededMessage(_ completion: @escaping SuccessCompletion) {
        let action = UIAlertAction(title: Localized("payment_message_button"), style: .default, handler: completion)
        
        let alertController = UIAlertController(title: Localized("payment_message_success_title"), message: Localized("payment_message_success_message"), preferredStyle: .alert)
        alertController.addAction(action)
        
        Navigator.presentModally(alertController)
    }
}
