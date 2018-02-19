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

#import "MSIDJsonObject.h"

@interface MSIDIdTokenWrapper : MSIDJsonObject
{
    NSString *_uniqueId;
    NSString *_userId;
    BOOL _userIdDisplayable;
}

// Default properties
@property (readonly) NSString *subject;
@property (readonly) NSString *preferredUsername;
@property (readonly) NSString *name;
@property (readonly) NSString *givenName;
@property (readonly) NSString *middleName;
@property (readonly) NSString *familyName;
@property (readonly) NSString *email;

// Derived properties
@property (readonly) NSString *uniqueId;
@property (readonly) NSString *userId;
@property (readonly) BOOL userIdDisplayable;

// Convinience properties
@property (readonly) NSString *rawIdToken;

- (instancetype)initWithRawIdToken:(NSString *)rawIdTokenString;
+ (NSString *)normalizeUserId:(NSString *)userId;

@end
