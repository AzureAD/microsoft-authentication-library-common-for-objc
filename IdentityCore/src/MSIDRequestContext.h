//
//  MSIDRequestContext.h
//  IdentityCore
//
//  Created by Olga Dalton on 11/21/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MSIDRequestContext

- (NSUUID *)correlationId;
- (NSString *)logComponent;
- (NSString *)telemetryRequestId;

@end
