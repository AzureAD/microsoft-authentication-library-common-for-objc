//
//  MSIDBrokerBrowserOperationResponse.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 2/26/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDBrokerBrowserOperationResponse.h"

@implementation MSIDBrokerBrowserOperationResponse

- (instancetype)initWithURLResponse:(NSHTTPURLResponse *)httpResponse body:(NSData *)httpBody
{
    self = [super init];
    if (self)
    {
        _httpResponse = httpResponse;
        _httpBody = httpBody;
    }
    
    return self;
}

- (void)handleResponse:(__unused NSURL *)url completeRequestBlock:(void (^)(NSHTTPURLResponse *, NSData *))completeRequestBlock
            errorBlock:(__unused void (^)(NSError *))errorBlock
{
    completeRequestBlock(self.httpResponse, self.httpBody);
}

- (void)handleError:(__unused NSError *)error errorBlock:(__unused void(^)(NSError *))errorBlock
   doNotHandleBlock:(void (^)(void))doNotHandleBlock
{
    doNotHandleBlock();
}

@end
