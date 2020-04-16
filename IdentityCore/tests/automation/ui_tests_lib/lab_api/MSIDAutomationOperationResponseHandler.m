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

#import "MSIDAutomationOperationResponseHandler.h"
#import "MSIDJsonSerializable.h"
#import "MSIDTestAutomationAccount.h"

@interface MSIDAutomationOperationResponseHandler()

@property (nonatomic) Class className;

@end

@implementation MSIDAutomationOperationResponseHandler

- (instancetype)initWithClass:(Class<MSIDJsonSerializable>)className
{
    self = [super init];
    
    if (self)
    {
        _className = className;
        
        if (![className conformsToProtocol:@protocol(MSIDJsonSerializable)])
        {
            return nil;
        }
    }
    
    return self;
}

- (id)responseFromData:(NSData *)response
                 error:(NSError **)error
{
    id jsonResponse = [NSJSONSerialization JSONObjectWithData:response options:0 error:error];
    if (!jsonResponse)
    {
        return nil;
    }
    
    NSMutableArray *resultArray = [NSMutableArray new];
    
    if ([jsonResponse isKindOfClass:[NSDictionary class]])
    {
        id result = [[self.className alloc] initWithJSONDictionary:jsonResponse error:nil];
        if (result) [resultArray addObject:result];
    }
    
    if ([jsonResponse isKindOfClass:[NSArray class]])
    {
        for (NSDictionary *responseDict in (NSArray *)jsonResponse)
        {
            id result = [[self.className alloc] initWithJSONDictionary:responseDict error:nil];
            if (result) [resultArray addObject:result];
        }
    }
    
    return resultArray;
}

@end
