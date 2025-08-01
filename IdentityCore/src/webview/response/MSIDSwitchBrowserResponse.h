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


#import "MSIDWebviewResponse.h"

@interface MSIDSwitchBrowserResponse : MSIDWebviewResponse

typedef NS_OPTIONS(NSInteger, MSIDSwitchBrowserModes) {
    BrowserModePrivateSession = 1 << 0,
    // Add future flags here
};

@property (nonatomic, readonly) NSString *actionUri;
@property (nonatomic, readonly) NSString *switchBrowserSessionToken;
@property (nonatomic, readonly) BOOL useEphemeralWebBrowserSession;
@property (nonatomic, readonly) NSString *state;

- (instancetype )init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)url
                redirectUri:(NSString *)redirectUri
               requestState:(NSString *)requestState
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error;

+ (BOOL)isDUNAActionUrl:(NSURL *)url operation:(NSString *)operation;

+ (BOOL)validateStateParameter:(NSString *)receivedState
                 expectedState:(NSString *)expectedState
                         error:(NSError *__autoreleasing*)error;
@end
