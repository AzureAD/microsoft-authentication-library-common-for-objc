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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import "MSIDBrowserRequestValidator.h"
#import "NSURL+MSIDAADUtils.h"

@implementation MSIDBrowserRequestValidator

+ (NSArray *)whitelistedPathComponents
{
    static dispatch_once_t onceToken;
    static NSArray *whitelistedComponents = nil;
    dispatch_once(&onceToken, ^{
        whitelistedComponents = @[@"oauth2", @"login", @"reprocess", @"SAS", @"appverify", @"saml2", @"kmsi", @"cmsi", @"resume", @"popbind", @"sso", @"forgetuser", @"SSPR", @"PIA", @"bind", @"consent", @"changepassword", @"fido", @"redeem", @"pmsi", @"kerberos", @"fidoauthorize", @"msalogout"]; // TODO: should we continue whitelisting or just handle all? What about SAML and WS-Fed?
    });
    
    return whitelistedComponents;
}

- (BOOL)shouldHandleURL:(nonnull NSURL *)url {
    if (url.pathComponents.count < 2)
    {
        return NO;
    }
    
    if ([url msidContainsPathComponents:[self.class whitelistedPathComponents]])
    {
        return YES;
    }
    
    return NO;
}

@end
