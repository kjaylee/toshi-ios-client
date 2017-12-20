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

extension CGFloat {
    
    static var lineHeight: CGFloat {
        return 1 / UIScreen.main.scale
    }
}

final class Theme: NSObject {}

extension Theme {
    
    @objc static func setupBasicAppearance() {
        let navBarAppearance = UINavigationBar.appearance()
        navBarAppearance.titleTextAttributes = [.font: Theme.semibold(size: 17), .foregroundColor: Theme.navigationTitleTextColor]
        navBarAppearance.tintColor = Theme.tintColor
        navBarAppearance.barTintColor = Theme.navigationBarColor
        
        let barButtonAppearance = UIBarButtonItem.appearance(whenContainedInInstancesOf: [UINavigationBar.self])
        barButtonAppearance.setTitleTextAttributes([.font: Theme.regular(size: 17), .foregroundColor: Theme.tintColor], for: .normal)
        
        let alertAppearance = UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        alertAppearance.tintColor = Theme.tintColor
    }
}

extension Theme {
    
    static var lightTextColor: UIColor {
        return .white
    }

    static var mediumTextColor: UIColor {
        return UIColor(hex: "99999D")
    }

    static var darkTextColor: UIColor {
        return .black
    }

    static var greyTextColor: UIColor {
        return UIColor(hex: "A4A4AB")
    }

    static var lightGreyTextColor: UIColor {
        return UIColor(hex: "7D7C7C")
    }

    static var lighterGreyTextColor: UIColor {
        return UIColor(hex: "F3F3F3")
    }

    @objc static var tintColor: UIColor {
        #if TOSHIDEV
            return UIColor(hex: "007AFF")
        #else
            return UIColor(hex: "01C236")
        #endif
    }

    static var sectionTitleColor: UIColor {
        return UIColor(hex: "78787D")
    }

    @objc static var viewBackgroundColor: UIColor {
        return .white
    }

    static var unselectedItemTintColor: UIColor {
        return UIColor(hex: "979ca4")
    }
    
    static var lightGrayBackgroundColor: UIColor {
        return UIColor(hex: "EFEFF4")
    }

    static var inputFieldBackgroundColor: UIColor {
        return UIColor(hex: "F1F1F1")
    }
    
    static var chatInputFieldBackgroundColor: UIColor {
        return UIColor(hex: "FAFAFA")
    }

    @objc static var navigationTitleTextColor: UIColor {
        return .black
    }

    @objc static var navigationBarColor: UIColor {
        return UIColor(hex: "F7F7F8")
    }

    static var borderColor: UIColor {
        return UIColor(hex: "D7DBDC")
    }

    static var actionButtonTitleColor: UIColor {
        return UIColor(hex: "0BBEE3")
    }

    static var ratingBackground: UIColor {
        return UIColor(hex: "D1D1D1")
    }

    static var ratingTint: UIColor {
        return UIColor(hex: "EB6E00")
    }

    static var passphraseVerificationContainerColor: UIColor {
        return UIColor(hex: "EAEBEC")
    }

    static var cellSelectionColor: UIColor {
        return UIColor(white: 0.95, alpha: 1)
    }

    static var separatorColor: UIColor {
        return UIColor(white: 0.95, alpha: 1)
    }
    
    static var incomingMessageBackgroundColor: UIColor {
        return UIColor(hex: "ECECEE")
    }

    static var outgoingMessageTextColor: UIColor {
        return .white
    }

    static var incomingMessageTextColor: UIColor {
        return .black
    }

    static var errorColor: UIColor {
        return UIColor(hex: "FF0000")
    }

    static var offlineAlertBackgroundColor: UIColor {
        return UIColor(hex: "5B5B5B")
    }

    static var inactiveButtonColor: UIColor {
        return UIColor(hex: "B6BCBF")
    }
}

extension Theme {
    
    private static func dynamicType(for preferredFont: UIFont, withStyle style: UIFontTextStyle, inSizeRange range: ClosedRange<CGFloat>) -> UIFont {
        let font: UIFont
        
        if #available(iOS 11.0, *) {
            let metrics = UIFontMetrics(forTextStyle: style)
            font = metrics.scaledFont(for: preferredFont, maximumPointSize: range.upperBound)
        } else {
            font = .preferredFont(forTextStyle: style)
        }
        
        let augmentedFontSize = font.pointSize.clamp(to: range)
        
        return font.withSize(augmentedFontSize)
    }
    
    @objc static func emoji() -> UIFont {
        return .systemFont(ofSize: 50)
    }
    
    static func preferredFootnote(range: ClosedRange<CGFloat> = 13...30) -> UIFont {
        return dynamicType(for: regular(size: 13), withStyle: .footnote, inSizeRange: range)
    }
     
    static func preferredFootnoteBold(range: ClosedRange<CGFloat> = 13...30) -> UIFont {
        return dynamicType(for: bold(size: 13), withStyle: .footnote, inSizeRange: range)
    }

    static func preferredTitle1(range: ClosedRange<CGFloat> = 34...40) -> UIFont {
        return dynamicType(for: bold(size: 34), withStyle: .title1, inSizeRange: range)
    }
    
    static func preferredTitle2(range: ClosedRange<CGFloat> = 22...35) -> UIFont {
        return dynamicType(for: bold(size: 22), withStyle: .title2, inSizeRange: range)
    }

    static func preferredTitle3(range: ClosedRange<CGFloat> = 20...30) -> UIFont {
        return dynamicType(for: regular(size: 16), withStyle: .title3, inSizeRange: range)
    }
    
    static func preferredRegular(range: ClosedRange<CGFloat> = 17...30) -> UIFont {
        return dynamicType(for: regular(size: 17), withStyle: .body, inSizeRange: range)
    }
    
    static func preferredRegularText(range: ClosedRange<CGFloat> = 17...30) -> UIFont {
        return dynamicType(for: regularText(size: 17), withStyle: .body, inSizeRange: range)
    }
    
    static func preferredRegularMedium(range: ClosedRange<CGFloat> = 17...30) -> UIFont {
        return dynamicType(for: medium(size: 17), withStyle: .callout, inSizeRange: range)
    }
    
    static func preferredRegularSmall(range: ClosedRange<CGFloat> = 16...30) -> UIFont {
        return dynamicType(for: regular(size: 16), withStyle: .subheadline, inSizeRange: range)
    }
    
    static func preferredSemibold(range: ClosedRange<CGFloat> = 17...30) -> UIFont {
        return dynamicType(for: semibold(size: 17), withStyle: .headline, inSizeRange: range)
    }
    
    /* Default Fonts */
    @objc static func light(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "SFProDisplay-Light", size: size) else { fatalError("This font should be available.") }
        return font
    }
    
    @objc static func regular(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "SFProDisplay-Regular", size: size) else { fatalError("This font should be available.") }
        return font
    }
    
    @objc static func semibold(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "SFProDisplay-Semibold", size: size) else { fatalError("This font should be available.") }
        return font
    }
    
    @objc static func bold(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "SFProDisplay-Bold", size: size) else { fatalError("This font should be available.") }
        return font
    }
    
    @objc static func medium(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "SFProDisplay-Medium", size: size) else { fatalError("This font should be available.") }
        return font
    }
    
    /* Text Fonts */
    @objc static func regularText(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "SFUIText-Regular", size: size) else { fatalError("This font should be available.") }
        return font
    }
}
