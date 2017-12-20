platform :ios, '10.0'

inhibit_all_warnings!

abstract_target 'CocoaPods' do
  # Things which can't be installed via Carthage because of C code
  pod 'AxolotlKit',  git: 'https://github.com/WhisperSystems/SignalProtocolKit.git'
  pod 'SignalServiceKit', git: 'https://github.com/toshiapp/Signal-iOS.git'

  # Grabs from the head of this repo, which allows SignalServiceKit to compile properly
  pod 'SocketRocket', git: 'https://github.com/facebook/SocketRocket.git'
  
  # Used to get our pulled out `PropertlyListPreferences.m` to compile properly
  pod 'CocoaLumberjack', '~> 3.3.0'

  # Things which can't be installed via carthage because they contain scripts
  pod 'Fabric', '~> 1.7.2'
  pod 'Crashlytics', '~>3.9.3'
  pod 'SwiftLint', '~>0.24.0'

  target 'Development' do
      
  end

  target 'Distribution' do

  end

  target 'Debug' do

  end

  target 'Tests' do
	
  end
end
