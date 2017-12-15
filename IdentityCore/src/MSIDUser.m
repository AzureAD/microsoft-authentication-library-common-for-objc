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

#import "MSIDUser.h"
#import "MSIDClientInfo.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDIdToken.h"

@implementation MSIDUser

- (instancetype)init
{
    return [self initWithUpn:nil
                        utid:nil
                         uid:nil];
}

- (instancetype)initWithUpn:(NSString *)upn
                       utid:(NSString *)utid
                        uid:(NSString *)uid
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self->_upn = upn;
    self->_utid = utid;
    self->_uid = uid;

    return self;
}

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
{
    NSString *uid = nil;
    NSString *utid = nil;
    
    if ([response isKindOfClass:[MSIDAADTokenResponse class]])
    {
        MSIDAADTokenResponse *aadTokenResponse = (MSIDAADTokenResponse *)response;
        uid = aadTokenResponse.clientInfo.uid;
        utid = aadTokenResponse.clientInfo.utid;
    }
    
    NSString *userId = response.idTokenObj.userId;
    return [self initWithUpn:userId utid:utid uid:uid];
}

- (NSString *)userIdentifier
{
    if (self.uid && self.uid)
    {
        return [NSString stringWithFormat:@"%@.%@", self.uid, self.utid];
    }
    return nil;    
}

@end
