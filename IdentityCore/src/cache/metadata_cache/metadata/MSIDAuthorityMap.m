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

#import "MSIDAuthorityMap.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDCache.h"
#import "MSIDAuthority.h"

@implementation MSIDAuthorityMap
{
    MSIDCache *_authorityMap;
}

- (instancetype)initWithAccountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                                 clientId:(NSString *)clientId
{
    if (!accountIdentifier || !clientId) return nil;
    
    self = [super init];
    if (self)
    {
        self.accountIdentifier = accountIdentifier;
        self.clientId = clientId;
        _authorityMap = [MSIDCache new];
    }
    return self;
}

- (BOOL)addMappingWithRequestAuthority:(MSIDAuthority *)requestAuthority
                     internalAuthority:(MSIDAuthority *)internalAuthority
{
    if (!internalAuthority.url.absoluteString || !internalAuthority.url.absoluteString) return NO;
    
    [_authorityMap setObject:internalAuthority.url.absoluteString forKey:internalAuthority.url.absoluteString];
    return YES;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    //TODO
    return nil;
}

- (NSDictionary *)jsonDictionary
{
    //TODO
    return nil;
}

@end
