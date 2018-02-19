//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDAADV1IdToken.h"

#define ID_TOKEN_UPN                @"upn"
#define ID_TOKEN_IDP                @"idp"
#define ID_TOKEN_OID                @"oid"
#define ID_TOKEN_TID                @"tid"
#define ID_TOKEN_GUEST_ID           @"altsecid"
#define ID_TOKEN_UNIQUE_NAME        @"unique_name"

@implementation MSIDAADV1IdToken

MSID_JSON_ACCESSOR(ID_TOKEN_UPN, upn)
MSID_JSON_ACCESSOR(ID_TOKEN_IDP, identityProvider)
MSID_JSON_ACCESSOR(ID_TOKEN_OID, objectId)
MSID_JSON_ACCESSOR(ID_TOKEN_TID, tenantId)
MSID_JSON_ACCESSOR(ID_TOKEN_GUEST_ID, guestId)
MSID_JSON_ACCESSOR(ID_TOKEN_UNIQUE_NAME, uniqueName)

- (instancetype)initWithRawIdToken:(NSString *)rawIdTokenString
{
    self = [super initWithRawIdToken:rawIdTokenString];
    
    if (self)
    {
        // Set uniqueId
        NSString *uniqueId = self.objectId;
        
        if ([NSString msidIsStringNilOrBlank:uniqueId])
        {
            uniqueId = self.subject;
        }
        
        _uniqueId = [MSIDIdTokenWrapper normalizeUserId:uniqueId];
        
        // Set userId (ADAL fallbacks)
        if (![NSString msidIsStringNilOrBlank:self.upn])
        {
            _userId = self.upn;
            _userIdDisplayable = YES;
        }
        else if (![NSString msidIsStringNilOrBlank:self.email])
        {
            _userId = self.email;
            _userIdDisplayable = YES;
        }
        else if (![NSString msidIsStringNilOrBlank:self.subject])
        {
            _userId = self.subject;
            _userIdDisplayable = NO;
        }
        else if (![NSString msidIsStringNilOrBlank:self.objectId])
        {
            _userId = self.objectId;
            _userIdDisplayable = NO;
        }
        else if (![NSString msidIsStringNilOrBlank:self.uniqueName])
        {
            _userId = self.uniqueName;
            _userIdDisplayable = YES;
        }
        else if (![NSString msidIsStringNilOrBlank:self.guestId])
        {
            _userId = self.guestId;
            _userIdDisplayable = NO;
        }
        
        _userId = [MSIDIdTokenWrapper normalizeUserId:_userId];
    }
    
    return self;
}

@end
