//
//  MSIDAppMetadataCacheQuery.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 10/23/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDAppMetadataCacheQuery.h"

@implementation MSIDAppMetadataCacheQuery

- (BOOL)exactMatch
{
    return self.clientId && self.environment;
}

@end
