// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import "MSIDExtendedTokenCacheDataSource.h"

// TODO: Use a subclass or protocol: https://identitydivision.visualstudio.com/DevEx/_workitems/edit/660964
@interface MSIDMacKeychainTokenCache : NSObject <MSIDExtendedTokenCacheDataSource>

/*!
 The name of the group to be used by default when creating an instance of MSIDKeychainTokenCache,
 the default value is com.microsoft.identity.universalstorage.

 If set to 'nil' the main bundle's identifier will be used instead.

 Because the keychain usage is different on macOS than on iOS, note that this group is used
 for keychain query filtering, not as an actual keychain group.

 NOTE: Once an authentication context has been created with the default keychain
 group, or +[MSIDMacKeychainTokenCache defaultKeychainCache] has been called, then
 this value cannot be changed. Doing so will throw an exception.
 */
@property (class, nullable) NSString *defaultKeychainGroup;

/*!
 Default cache. Will be initialized with defaultKeychainGroup.
 */
@property (class, readonly, nonnull) MSIDMacKeychainTokenCache *defaultKeychainCache;

/*!
 Actual keychain sharing group used for queries.
 May contain team id (<team id>.<keychain group>)
 */
@property (readonly, nonnull) NSString *keychainGroup;

/*!
 Initialize with keychainGroup and trustedApplications.
 @param keychainGroup Optional. If the application needs to share the cached tokens
 with other applications from the same vendor, the app will need to specify the
 shared group here.  If set to 'nil' the main bundle's identifier will be used instead.
 
 @param trustedApplications Optional. A list of SecTrustedApplicationRef that describes
 all the applications that should have access to the credentials that is stored in this
 cache.  If set to 'nil' the current application path will be used as the one
 trusted application.

 NOTE: init: initializes keychainGroup with defaultKeychainGroup and trustedApplications as nil.

 See Apple's keychain services documentation for details.
 */
- (nullable instancetype)initWithGroup:(nullable NSString *)keychainGroup
                   trustedApplications:(nullable NSArray *)trustedApplications
                                 error:(NSError * _Nullable __autoreleasing * _Nullable)error;


@end
