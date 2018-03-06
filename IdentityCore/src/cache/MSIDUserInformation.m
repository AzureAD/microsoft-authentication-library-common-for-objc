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

#import "MSIDUserInformation.h"
#import "MSIDAADV1IdTokenWrapper.h"

@implementation MSIDUserInformation

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithRawIdToken:(NSString *)rawIdTokenString
{
    self = [super init];
    
    if (self)
    {
        _rawIdToken = rawIdTokenString;
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _rawIdToken = [coder decodeObjectOfClass:[NSString class] forKey:@"rawIdToken"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_rawIdToken forKey:@"rawIdToken"];
    
#if TARGET_OS_IPHONE
    // These are needed for back-compat with ADAL 1.x
    // ADAL 1.2x only supported AAD v1, so use MSIDAADV1IdToken
    MSIDAADV1IdTokenWrapper *tokenObj = [[MSIDAADV1IdTokenWrapper alloc] initWithRawIdToken:_rawIdToken];
    [coder encodeObject:tokenObj.jsonDictionary forKey:@"allClaims"];
    [coder encodeObject:tokenObj.userId forKey:@"userId"];
    [coder encodeBool:tokenObj.userIdDisplayable forKey:@"userIdDisplayable"];
#endif
}

@end
