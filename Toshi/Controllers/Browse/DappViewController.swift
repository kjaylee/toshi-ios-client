//
//  DappViewController.swift
//  Debug
//
//  Created by Ellen Shapiro (Work) on 12/19/17.
//  Copyright © 2017 Bakken&Baeck. All rights reserved.
//

import SweetUIKit
import UIKit
import TinyConstraints

final class DappViewController: UIViewController {
    
    private let dapp: Dapp
    
    private let avatarHeight: CGFloat = 60
    
    // MARK: Normal Views
    
    private lazy var avatarImageView = AvatarImageView()
    
    private lazy var mainLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.preferredTitle2()
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var urlLabel: UILabel = {
        let label = UILabel()
        label.textColor = Theme.lightGreyTextColor

        return label
    }()
    
    private lazy var enterButton: ActionButton = {
        let button = ActionButton(margin: 30)
        button.title = Localized("dapp_button_enter")
        button.addTarget(self,
                         action: #selector(didTapEnterButton(_:)),
                         for: .touchUpInside)
        
        return button
    }()
    
    // MARK: StackViews
    
    private lazy var headerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.alignment = .center
        
        stackView.addArrangedSubview(avatarImageView)
        
        avatarImageView.height(avatarHeight)
        avatarImageView.width(avatarHeight)
        
        stackView.addArrangedSubview(mainLabel)
        
        return stackView
    }()
    
    private lazy var primaryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        
        stackView.addArrangedSubview(headerStackView)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(urlLabel)
        stackView.addArrangedSubview(enterButton)
        
        enterButton.height(44)
        
        return stackView
    }()
    
    // MARK: - Initialization
    
    required init(with dapp: Dapp) {
        self.dapp = dapp
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = Theme.viewBackgroundColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(primaryStackView)
        
        let topAnchor: NSLayoutYAxisAnchor
        
        if #available(iOS 11.0, *) {
            topAnchor = view.safeAreaLayoutGuide.topAnchor
        } else {
            topAnchor = view.topAnchor
        }
        
        primaryStackView.top(to: view, topAnchor, offset: 16)
        primaryStackView.leftToSuperview(offset: 16)
        primaryStackView.rightToSuperview(offset: 16)
    
        configure(for: dapp)
    }
    
    // MARK: - Configuration
    
    private func configure(for dapp: Dapp) {
        title = dapp.name
        mainLabel.text = dapp.name
        descriptionLabel.text = dapp.description
        urlLabel.text = dapp.url.absoluteString
        
        AvatarManager.shared.avatar(for: dapp.avatarUrlString, completion: { [weak self] image, _ in
            self?.avatarImageView.image = image
        })
    }
    
    // MARK: - Action Targets
    
    @objc private func didTapEnterButton(_ sender: UIButton) {
        let sofaWebController = SOFAWebController()
        sofaWebController.load(url: dapp.url)
        
        navigationController?.pushViewController(sofaWebController, animated: true)
    }
}
