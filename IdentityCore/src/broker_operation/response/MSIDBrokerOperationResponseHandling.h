//
//  MSIDBrokerOperationResponseHandling.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 2/26/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDBrokerOperationResponse.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MSIDBrokerOperationResponseHandling <NSObject>

- (void)handleResponse:(MSIDBrokerOperationResponse *)response
                   url:(NSURL *)url
  completeRequestBlock:(__unused void (^)(NSHTTPURLResponse *, NSData *))completeRequestBlock
            errorBlock:(__unused void (^)(NSError *))errorBlock;

- (void)handleError:(NSError *)error
         errorBlock:(void(^)(NSError *))errorBlock
   doNotHandleBlock:(void (^)(void))doNotHandleBlock;

@end

NS_ASSUME_NONNULL_END
