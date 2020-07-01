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


#import <Foundation/Foundation.h>
#import "MSIDBrokerInstallOperation.h"
#import "MSIDWebviewResponse.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDAppExtensionUtil.h"

@interface MSIDBrokerInstallOperation()

@property (nonatomic) MSIDWebWPJResponse *response;

@end

@implementation MSIDBrokerInstallOperation

- (nullable instancetype)initWithResponse:(MSIDWebviewResponse *)response
                                    error:(NSError **)error
{
    #if TARGET_OS_IPHONE
    self = [super initWithResponse:response
                             error:error];
    if (self)
    {
        if (![response isKindOfClass:MSIDWebWPJResponse.class])
        {
            return nil;
        }
        _response = (MSIDWebWPJResponse *)response;
    }

    return self;
    #else
    return nil
    #endif
}

- (void)invokeWithCompletion:(MSIDBaseOperationCompletionHandler)completion
{
    #if TARGET_OS_IPHONE
    if ([NSString msidIsStringNilOrBlank:self.response.appInstallLink])
    {
        NSError *appInstallError = MSIDCreateError(MSIDErrorDomain,
                                                   MSIDErrorInternal,
                                                   @"App install link is missing. Incorrect URL returned from server",
                                                   nil,
                                                   nil,
                                                   nil,
                                                   nil,
                                                   nil,
                                                   YES);
        completion(NO, appInstallError);
        return;
    }
    
    [MSIDAppExtensionUtil sharedApplicationOpenURL:[NSURL URLWithString:self.response.appInstallLink]
                                               options:nil
                                     completionHandler:^(BOOL success)
    {
        if (!success)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to open broker URL.");
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to open broker URL.", nil, nil, nil, nil, nil, NO);
            completion(NO, error);
            return;
        }

        completion(YES, nil);
    }];
    #else
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInternal,
                                         @"Trying to install broker on macOS, where it's not currently supported",
                                         nil,
                                         nil,
                                         nil,
                                         nil,
                                         nil,
                                         YES);
        completion(NO, error);
    #endif
}

@end
