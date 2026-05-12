//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

#import "MSIDASWebAuthHandoffConfiguration.h"

@implementation MSIDASWebAuthHandoffConfiguration

- (instancetype)initWithHandoffURL:(NSURL *)url
                useEphemeralSession:(BOOL)useEphemeral
                            purpose:(MSIDSystemWebviewPurpose)purpose
                  additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)headers
{
    self = [super init];
    if (self)
    {
        _handoffURL = url;
        _useEphemeralSession = useEphemeral;
        _purpose = purpose;
        _additionalHeaders = [headers copy];
    }
    return self;
}

@end
