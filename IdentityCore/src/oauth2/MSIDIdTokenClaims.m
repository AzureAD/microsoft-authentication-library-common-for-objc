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

#import "MSIDIdTokenClaims.h"
#import "MSIDHelpers.h"

#define ID_TOKEN_SUBJECT             @"sub"
#define ID_TOKEN_PERFERRED_USERNAME  @"preferred_username"
#define ID_TOKEN_NAME                @"name"
#define ID_TOKEN_GIVEN_NAME          @"given_name"
#define ID_TOKEN_FAMILY_NAME         @"family_name"
#define ID_TOKEN_MIDDLE_NAME         @"middle_name"
#define ID_TOKEN_EMAIL               @"email"

@implementation MSIDIdTokenClaims

MSID_JSON_ACCESSOR(ID_TOKEN_SUBJECT, subject)
MSID_JSON_ACCESSOR(ID_TOKEN_PERFERRED_USERNAME, preferredUsername)
MSID_JSON_ACCESSOR(ID_TOKEN_NAME, name)
MSID_JSON_ACCESSOR(ID_TOKEN_GIVEN_NAME, givenName)
MSID_JSON_ACCESSOR(ID_TOKEN_FAMILY_NAME, familyName)
MSID_JSON_ACCESSOR(ID_TOKEN_MIDDLE_NAME, middleName)
MSID_JSON_ACCESSOR(ID_TOKEN_EMAIL, email)

- (instancetype)initWithRawIdToken:(NSString *)rawIdTokenString
{
    if ([NSString msidIsStringNilOrBlank:rawIdTokenString])
    {
        return nil;
    }
    
    _rawIdToken = rawIdTokenString;
    
    NSArray* parts = [rawIdTokenString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
    if (parts.count != 3)
    {
        MSID_LOG_WARN(nil, @"Id token is invalid.");
        return nil;
    }
    
    NSData *decoded =  [[parts[1] msidBase64UrlDecode] dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    if (!(self = [super initWithJSONData:decoded error:&error]))
    {
        if (error)
        {
            MSID_LOG_WARN(nil, @"Id token is invalid. Error: %@", error.localizedDescription);
        }
        return nil;
    }
    
    [self initDerivedProperties];
    
    return self;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    self = [super initWithJSONDictionary:json error:error];

    if (self)
    {
        [self initDerivedProperties];
    }

    return self;
}

- (void)initDerivedProperties
{
    _uniqueId = [MSIDHelpers normalizeUserId:self.subject];
    _userId = [MSIDHelpers normalizeUserId:self.subject];
    _userIdDisplayable = NO;
}

- (BOOL)matchesLegacyUserId:(NSString *)legacyUserId
{
    return [self.preferredUsername isEqualToString:legacyUserId]
                    || [self.email isEqualToString:legacyUserId]
                    || [self.subject isEqualToString:legacyUserId];
}

- (NSString *)username
{
    return self.preferredUsername ? self.preferredUsername : self.userId;
}

- (NSString *)alternativeAccountId
{
    return nil;
}

- (NSString *)realm
{
    return nil;
}

@end
