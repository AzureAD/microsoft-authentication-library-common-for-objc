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

#import "MSIDAutomationPolicyToggleAPIRequest.h"

@implementation MSIDAutomationPolicyToggleAPIRequest

#pragma - Lab Request

- (NSString *)requestOperationPath
{
    return self.policyEnabled ? @"EnablePolicy" : @"DisablePolicy";
}

- (NSString *)keyvaultNameKey
{
    return self.policyEnabled ? @"enable_policy_api_keyvault" : @"disable_policy_api_keyvault";
}

- (NSArray<NSURLQueryItem *> *)queryItems
{
    NSString *policyType = self.policyTypeAsString;
    
    if (!policyType)
    {
        return nil;
    }
    
    return @[[[NSURLQueryItem alloc] initWithName:@"Policy" value:policyType]];
}

#pragma mark - Helpers

- (NSString *)policyTypeAsString
{
    switch (self.automationPolicy)
    {
        case MSIDGlobalMFAPolicy:
            return @"GLOBALMFA";
            
        case MSIDMFAOnSPOPolicy:
            return @"MFAONSPO";
            
        case MSIDMFAOnEXOPolicy:
            return @"MFAONEXO";
            
        case MSIDMamCaPolicy:
            return @"MAMCA";
            
        case MSIDMdmCaPolicy:
            return @"MDMCA";
            
        default:
            return nil;
    }
}

@end
