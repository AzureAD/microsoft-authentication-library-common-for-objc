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

#import "MSIDLegacyTokenResponseValidator.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"

@implementation MSIDLegacyTokenResponseValidator

- (BOOL)validateTokenResult:(MSIDTokenResult *)tokenResult
              configuration:(MSIDConfiguration *)configuration
             requestAccount:(MSIDAccountIdentifier *)accountIdentifier
              correlationID:(NSUUID *)correlationID
                      error:(NSError **)error
{
    // Validate correct account returned
    BOOL accountValid = [self checkAccount:tokenResult
                         accountIdentifier:accountIdentifier
                             correlationID:correlationID];

    if (!accountValid)
    {
        MSID_LOG_ERROR_CORR(correlationID, @"Different account returned");
        MSID_LOG_ERROR_CORR_PII(correlationID, @"Different account returned, Input account id %@, returned account ID %@, local account ID %@", accountIdentifier.displayableId, tokenResult.account.accountIdentifier.displayableId, tokenResult.account.localAccountId);

        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMismatchedAccount, @"Different user was returned by the server then specified in the acquireToken call. If this is a new sign in use and ADUserIdentifier is of OptionalDisplayableId type, pass in the userId returned on the initial authentication flow in all future acquireToken calls.", nil, nil, nil, correlationID, nil);
        }

        return NO;
    }

    return YES;
}

- (BOOL)checkAccount:(MSIDTokenResult *)tokenResult
   accountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
       correlationID:(NSUUID *)correlationID
{
    MSID_LOG_VERBOSE_CORR(correlationID, @"Checking returned account");
    MSID_LOG_VERBOSE_CORR_PII(correlationID, @"Checking returned account, Input account id %@, returned account ID %@, local account ID %@", accountIdentifier.displayableId, tokenResult.account.accountIdentifier.displayableId, tokenResult.account.localAccountId);

    if (!accountIdentifier.displayableId)
    {
        return YES;
    }

    if (!tokenResult.account)
    {
        return NO;
    }

    switch (accountIdentifier.legacyAccountIdentifierType)
    {
        case MSIDLegacyIdentifierTypeRequiredDisplayableId:
        {
            return [accountIdentifier.displayableId.lowercaseString isEqualToString:tokenResult.account.accountIdentifier.displayableId.lowercaseString];
        }

        case MSIDLegacyIdentifierTypeUniqueNonDisplayableId:
        {
            return [accountIdentifier.displayableId.lowercaseString isEqualToString:tokenResult.account.localAccountId.lowercaseString];
        }
        case MSIDLegacyIdentifierTypeOptionalDisplayableId:
        {
            return YES;
        }

        default:
            return NO;
    }
}

@end
