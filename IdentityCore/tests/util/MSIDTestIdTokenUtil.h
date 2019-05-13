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

#import <Foundation/Foundation.h>

@interface MSIDTestIdTokenUtil : NSObject

+ (NSString *)defaultV2IdToken;
+ (NSString *)defaultV1IdToken;
+ (NSString *)defaultName;
+ (NSString *)defaultUsername;
+ (NSString *)defaultTenantId;
+ (NSString *)defaultUniqueId;

+ (NSString *)idTokenWithName:(NSString *)name
            preferredUsername:(NSString *)preferredUsername;

+ (NSString *)idTokenWithName:(NSString *)name
            preferredUsername:(NSString *)preferredUsername
                          oid:(NSString *)oid
                     tenantId:(NSString *)tid;

+ (NSString *)idTokenWithName:(NSString *)name
                          upn:(NSString *)upn
                          oid:(NSString *)oid
                     tenantId:(NSString *)tid;

+ (NSString *)idTokenWithName:(NSString *)name
                          upn:(NSString *)upn
                     tenantId:(NSString *)tid
             additionalClaims:(NSDictionary *)additionalClaims;

+ (NSString *)idTokenWithPreferredUsername:(NSString *)username
                                   subject:(NSString *)subject;

+ (NSString *)idTokenWithPreferredUsername:(NSString *)username
                                   subject:(NSString *)subject
                                 givenName:(NSString *)givenName
                                familyName:(NSString *)familyName;

+ (NSString *)idTokenWithPreferredUsername:(NSString *)username
                                   subject:(NSString *)subject
                                 givenName:(NSString *)givenName
                                familyName:(NSString *)familyName
                                      name:(NSString *)name;

+ (NSString *)idTokenWithPreferredUsername:(NSString *)username
                                   subject:(NSString *)subject
                                 givenName:(NSString *)givenName
                                familyName:(NSString *)familyName
                                      name:(NSString *)name
                                   version:(NSString *)version;

+ (NSString *)idTokenWithPreferredUsername:(NSString *)username
                                   subject:(NSString *)subject
                                 givenName:(NSString *)givenName
                                familyName:(NSString *)familyName
                                      name:(NSString *)name
                                   version:(NSString *)version
                                       tid:(NSString *)tid;

@end
