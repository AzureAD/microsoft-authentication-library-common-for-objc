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

#import "MSIDApplicationTestUtil.h"
#import <objc/message.h>

BOOL (^s_onOpenUrl)(NSURL *url, NSDictionary<NSString *, id> *options) = nil;
static NSArray *s_canOpenURLSchemes = nil;

@implementation MSIDApplicationTestUtil

+ (void)setCanOpenURLSchemes:(NSArray *)canOpenURLSchemes
{
    s_canOpenURLSchemes = canOpenURLSchemes;
}

+ (NSArray *)canOpenURLSchemes
{
    return s_canOpenURLSchemes;
}

+ (void)onOpenURL:(BOOL (^)(NSURL *url, NSDictionary<NSString *, id> *options))openUrlBlock
{
    s_onOpenUrl = openUrlBlock;
}

+ (void)reset
{
    s_onOpenUrl = nil;
}

@end


@interface UIApplication (TestOverride)

@end


#pragma mark push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
@implementation UIApplication (TestOverride)

+ (void)load
{
    
    Method openUrlStr = class_getInstanceMethod(UIApplication.class, @selector(openURL:));
    Method msidOpenUrlStr = class_getInstanceMethod(UIApplication.class, @selector(msidOpenURL:));
    method_exchangeImplementations(openUrlStr, msidOpenUrlStr);
    
    Method openUrlOptionsCompletionHandlerStr = class_getInstanceMethod(UIApplication.class, @selector(openURL:options:completionHandler:));
    Method msidOpenUrlOptionsCompletionHandlerStr = class_getInstanceMethod(UIApplication.class, @selector(msidOpenURL:options:completionHandler:));
    method_exchangeImplementations(openUrlOptionsCompletionHandlerStr, msidOpenUrlOptionsCompletionHandlerStr);
    
    Method canOpenUrlStr = class_getInstanceMethod(UIApplication.class, @selector(canOpenURL:));
    Method msidCanOpenUrlStr = class_getInstanceMethod(UIApplication.class, @selector(msidCanOpenURL:));
    method_exchangeImplementations(canOpenUrlStr, msidCanOpenUrlStr);
}

- (BOOL)msidOpenURL:(NSURL *)url
{
    if (!s_onOpenUrl)
    {
        NSAssert(s_onOpenUrl, @"Some test isn't properly waiting for the flow to complete");
    }
    
    return s_onOpenUrl(url, nil);
}

- (BOOL)msidCanOpenURL:(NSURL *)url
{
    if (s_canOpenURLSchemes)
    {
        return [s_canOpenURLSchemes containsObject:url.scheme];
    }
    
    return YES;
}

- (void)msidOpenURL:(NSURL*)url
        options:(NSDictionary<NSString *, id> *)options
completionHandler:(void (^ __nullable)(BOOL success))completionHandler
{
    completionHandler(s_onOpenUrl(url, options));
}

#pragma mark pop

@end
