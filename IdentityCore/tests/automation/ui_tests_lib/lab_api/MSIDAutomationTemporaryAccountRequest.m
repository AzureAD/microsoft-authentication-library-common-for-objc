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

#import "MSIDAutomationTemporaryAccountRequest.h"

@implementation MSIDAutomationTemporaryAccountRequest

#pragma mark - NSCopying

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    MSIDAutomationTemporaryAccountRequest *request = [super copyWithZone:zone];
    request->_accountType = _accountType;
    return request;
}

#pragma mark - Lab Request

- (NSString *)requestOperationPath
{
    return @"CreateTempUser";
}

- (NSString *)requestOperationCodeKey
{
    return @"create_user_api_code";
}

- (NSArray<NSURLQueryItem *> *)queryItems
{
    NSString *accountType = [self accountTypeAsString];
    
    if (!accountType)
    {
        return nil;
    }
    
    return @[[[NSURLQueryItem alloc] initWithName:@"usertype" value:accountType]];
}

- (NSString *)httpMethod
{
    return @"POST";
}

#pragma mark - Helpers

- (NSString *)accountTypeAsString
{
    switch (self.accountType)
    {
        case MSIDBasicTemporaryAccount:
            return @"Basic";
            
        case MSIDGlobalMFATemporaryAccount:
            return @"GLOBALMFA";
            
        case MSIDMFAOnSPOTemporaryAccount:
            return @"MFAONSPO";
            
        case MSIDMFAOnEXOTemporaryAccount:
            return @"MFAONEXO";
            
        case MSIDMamCaTemporaryAccount:
            return @"MAMCA";
            
        case MSIDMdmCaTemporaryAccount:
            return @"MDMCA";
            
        default:
            return nil;
    }
}

@end
