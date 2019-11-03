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

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 && !MSID_EXCLUDE_WEBKIT
#import "MSIDBrokerOperationTokenRequest.h"
#import "MSIDConstants.h"

@class WKWebView;
@class MSIDAccountIdentifier;
@class MSIDInteractiveRequestParameters;
@class ADBrokerRequest;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface MSIDBrokerOperationInteractiveTokenRequest : MSIDBrokerOperationTokenRequest

@property (nonatomic, nullable) MSIDAccountIdentifier *accountIdentifier;
@property (nonatomic, nullable) NSString *loginHint;
@property (nonatomic) MSIDPromptType promptType;

+ (instancetype)tokenRequestWithParameters:(MSIDInteractiveRequestParameters *)parameters
                                     error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
#endif
