//
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


#import "MSIDBrokerOperationRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationBrowserNativeMessageRequest : MSIDBrokerOperationRequest

@property (nonatomic) NSDictionary *payloadJson;
@property (nonatomic) NSString *parentProcessBundleIdentifier;
@property (nonatomic) NSString *parentProcessTeamId;
@property (nonatomic) NSString *parentProcessLocalizedName;

@property (nonatomic, readonly) NSString *callerBundleIdentifier;
@property (nonatomic, readonly) NSString *callerTeamIdentifier API_AVAILABLE(ios(14.0), macos(11.0)) API_UNAVAILABLE(watchos, tvos);
@property (nonatomic, readonly) NSString *localizedCallerDisplayName API_AVAILABLE(ios(14.0), macos(11.0)) API_UNAVAILABLE(watchos, tvos);
@property (nonatomic, readonly) NSString *localizedApplicationInfo API_AVAILABLE(ios(14.0), macos(11.0)) API_UNAVAILABLE(watchos, tvos);

@property (nonatomic, readonly) NSString *method;

@end

NS_ASSUME_NONNULL_END
