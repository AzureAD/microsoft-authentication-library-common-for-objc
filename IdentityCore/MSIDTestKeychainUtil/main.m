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

#import "MSIDBasicContext.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSIDClientInfo.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDDefaultAccountCacheQuery.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "NSString+MSIDExtensions.h"
#import <Foundation/Foundation.h>

@interface MSIDTestKeychainUtilDispatcher : NSObject
- (id)init;
- (NSString*) execute:(NSString*)params;
@property NSDictionary* inputParameters;
@end

@implementation MSIDTestKeychainUtilDispatcher

- (id)init {
    return [super init];
}

- (NSString*) execute:(NSString*)params {
    NSError *error;
    _inputParameters = [NSJSONSerialization JSONObjectWithData:[params dataUsingEncoding:NSUTF8StringEncoding]
                                                                options:0
                                                                  error:&error];
    if (error != nil) {
        return [self setResponse:@{@"getError": [NSString stringWithFormat:@"Couldn't parse input: '%@'", error]}];
    }
    NSDictionary* result = [self executeInternal];
    return [self setResponse:result];
}

- (NSString*)setResponse:(NSDictionary *)response {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

- (NSDictionary*) executeInternal {
    if ([_inputParameters[@"method"] isEqualToString:@"ReadAccount"]) {
        return [self readAccountTest];
    } else if ([_inputParameters[@"method"] isEqualToString:@"WriteAccount"]) {
        return [self writeAccountTest];
    }
    return @{@"status":@-1};
}

- (NSDictionary*) readAccountTest {
    return @{@"status":@0};
}

- (NSDictionary*) writeAccountTest {
    return @{@"status":@0};
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        /*
        for (int i = 0; i < argc; i++) {
            printf("arg[%d] = %s\n", i, argv[i]);
        }
        printf("\n");
         */
        if (argc >= 2) {
            NSString* input = [NSString stringWithUTF8String:argv[1]];
            MSIDTestKeychainUtilDispatcher* dispatcher = [MSIDTestKeychainUtilDispatcher new];
            NSString* result = [dispatcher execute:input];
            printf("%s\n", [result UTF8String]);
        }
    }
    return 0;
}
