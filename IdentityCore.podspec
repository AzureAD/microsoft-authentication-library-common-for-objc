Pod::Spec.new do |s|
  s.name             = 'IdentityCore'
  s.version          = '0.1.0'
  s.summary          = 'Microsoft Authentication Common Library for iOS'
  s.description      = <<-DESC
Common code used by both the Active Directory Authentication Library (ADAL) and the Microsoft Authentication Library (MSAL)
                       DESC

  s.homepage         = 'https://github.com/AzureAD/microsoft-authentication-library-common-for-objc'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Zayin Krige' => 'zkrige@gmail.com' }
  s.source           = { :git => 'https://github.com/AzureAD/microsoft-authentication-library-common-for-objc.git', :commit => "a21db2f" }
  s.ios.deployment_target = '10.0'

  s.source_files = 'IdentityCore/src/**/*.{h,m,c}', 'IdentityCore/tests/**/MSIDVersion.{h,m,c}'
  s.exclude_files = 'IdentityCore/src/**/MSIDTestIdTokenUtil.{h,m}'
  s.prefix_header_file = 'IdentityCore/src/IdentityCore.pch'
end
