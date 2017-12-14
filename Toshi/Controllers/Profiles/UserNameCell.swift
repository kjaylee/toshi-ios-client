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

import TinyConstraints
import UIKit

final class UserNameCell: UICollectionViewCell {
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.tintColor = Theme.tintColor
        return label
    }()
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                nameLabel.backgroundColor = Theme.tintColor
                nameLabel.textColor = Theme.inputFieldBackgroundColor
            } else {
                nameLabel.textColor = Theme.tintColor
                nameLabel.backgroundColor = Theme.inputFieldBackgroundColor
            }
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupNameLabel()
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Subview Setup
    
    private func setupNameLabel() {
        contentView.addSubview(nameLabel)
        nameLabel.edgesToSuperview()
    }
    
    // MARK: - Public API
    
    func setText(_ text: String) {
        nameLabel.text = text
    }
}
