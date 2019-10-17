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

#import "MSIDBrokerOperationTokenRequest+Parameteres.h"
#import "MSIDRequestParameters.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDVersion.h"

@implementation MSIDBrokerOperationTokenRequest (Parameteres)

+ (BOOL)fillRequest:(MSIDBrokerOperationTokenRequest *)request
     withParameters:(MSIDRequestParameters *)parameters
              error:(NSError **)error
{
    NSString *accessGroup = parameters.keychainAccessGroup ?: MSIDKeychainTokenCache.defaultKeychainGroup;
    __auto_type brokerKeyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:accessGroup];
        NSError *brokerError = nil;
    NSString *base64UrlKey = [brokerKeyProvider base64BrokerKeyWithContext:parameters
                                                                     error:&brokerError];
    
    if (!base64UrlKey)
    {
        // TODO: add telemetry.
        if (error) *error = brokerError;
        return NO;
    }
    
    request.brokerKey = base64UrlKey;
    request.clientVersion = [MSIDVersion sdkVersion];
    request.protocolVersion = 4;
    NSDictionary *clientMetadata = parameters.appRequestMetadata;
    request.clientAppVersion = clientMetadata[MSID_APP_VER_KEY];
    request.clientAppName = clientMetadata[MSID_APP_NAME_KEY];
    request.correlationId = parameters.correlationId;
    request.configuration = parameters.msidConfiguration;
    
    return YES;
}

@end
