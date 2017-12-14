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

// A collection view cell to facilitate collecting text input
final class TextInputCell: UICollectionViewCell {
    
    private(set) lazy var textField: UITextField = {
        let textField = UITextField()
        
        return textField
    }()
    
    weak var textFieldDelegate: UITextFieldDelegate? {
        didSet {
            textField.delegate = textFieldDelegate
        }
    }

    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupTextField()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupTextField() {
        contentView.addSubview(textField)
        
        let margin: CGFloat = 4
        textField.edgesToSuperview(insets: UIEdgeInsets(top: margin, left: margin, bottom: margin, right: -margin))
    }
    
    // MARK: - Sizing helpers
    
    func textFieldSize(forWidth width: CGFloat) -> CGSize {
        guard let text = textField.text else { return CGSize(width: 0, height: textField.frame.height) }
        
        let sizeConstraint = CGSize(width: width, height: textField.frame.height)
        
        let frame = (text as NSString).boundingRect(with: sizeConstraint,
                                                    options: [.usesLineFragmentOrigin],
                                                    attributes: [
                                                        .font: textField.font!
                                                    ],
                                                    context: nil)
        return frame.size
    }
    
}
