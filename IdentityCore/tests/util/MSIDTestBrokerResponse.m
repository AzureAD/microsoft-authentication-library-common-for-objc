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

#import "MSIDTestBrokerResponse.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestIdTokenUtil.h"
#import "NSDictionary+MSIDTestUtil.h"

@implementation MSIDTestBrokerResponse

+ (MSIDBrokerResponse *)testBrokerResponse
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    NSDictionary *brokerDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                       @"client_id": DEFAULT_TEST_CLIENT_ID,
                                       @"resource": DEFAULT_TEST_RESOURCE,
                                       @"access_token": DEFAULT_TEST_ACCESS_TOKEN,
                                       @"refresh_token": DEFAULT_TEST_REFRESH_TOKEN,
                                       @"expires_on": @"35674848",
                                       @"id_token": [MSIDTestIdTokenUtil defaultV1IdToken],
                                       @"x-broker-app-ver": @"1.2",
                                       @"vt": @YES,
                                       @"client_info": clientInfoString
                                       };
    
    return [[MSIDBrokerResponse alloc] initWithDictionary:brokerDictionary error:nil];
}

@end
