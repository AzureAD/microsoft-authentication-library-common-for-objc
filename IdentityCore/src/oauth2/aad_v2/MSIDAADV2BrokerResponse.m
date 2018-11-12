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

#import "MSIDAADV2BrokerResponse.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDBrokerResponse+Internal.h"
#import "MSIDAADV2TokenResponse.h"

@implementation MSIDAADV2BrokerResponse

MSID_FORM_ACCESSOR(@"scope", scope);

- (instancetype)initWithDictionary:(NSDictionary *)form
                             error:(NSError **)error
{
    self = [super initWithDictionary:form error:error];

    if (self)
    {
        NSString *errorUserinfoJSON = form[@"error_user_info"];
        _errorUserInfo = [NSDictionary msidDictionaryFromJsonData:[errorUserinfoJSON dataUsingEncoding:NSUTF8StringEncoding] error:nil];

        self.tokenResponse = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:form
                                                                              error:error];
    }

    return self;
}

- (NSString *)oauthErrorCode
{
    return self.errorUserInfo[@"oauth_error"];
}

- (NSString *)errorDescription
{
    return self.errorUserInfo[@"error_description"];
}

- (NSString *)subError
{
    return self.errorUserInfo[@"oauth_sub_error"];
}

- (NSString *)httpHeaders
{
    return self.errorUserInfo[@"http_headers"];
}

@end
