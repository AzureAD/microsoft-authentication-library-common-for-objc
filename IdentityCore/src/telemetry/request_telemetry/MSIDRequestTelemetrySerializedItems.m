//
//  MSIDRequestTelemetrySerializer.m
//  IdentityCore
//
//  Created by Mihai Petriuc on 5/4/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDRequestTelemetrySerializedItems.h"

@implementation MSIDRequestTelemetrySerializedItems

- (instancetype)initWithDefaultFields:(NSArray *)defaultFields errorInfo:(NSArray *)errorsInfo platformFields:(NSArray *)platformFields
{
    _defaultFields = defaultFields;
    _errorsInfo = errorsInfo;
    _platformFields = platformFields;
    return self;
}

- (NSString *)serializedDefaultFields
{
    if (self.defaultFields)
    {
        return [self.defaultFields componentsJoinedByString:@","];
    }
    else
    {
        return @"";
    }
}

- (NSString *)serializedErrorsInfoWithCurrentStringSize:(NSUInteger)startLength
{
    NSString *failedRequestsString = @"";
    NSString *errorMessagesString = @"";
    
    if (self.errorsInfo.count > 0)
    {
        //NSUInteger startLength = [telemetryString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        int lastIndex = (int)self.errorsInfo.count - 1;
        
        // Set first post in fencepost structure -- last item in string doesn't have comma at the end
        NSString *currentFailedRequest = [NSString stringWithFormat:@"%ld,%@", self.errorsInfo[lastIndex].apiId, self.errorsInfo[lastIndex].correlationId];
        NSString *currentErrorMessage = [NSString stringWithFormat:@"%@", self.errorsInfo[lastIndex].error];
        
        // Only add error info into string if the resulting string smaller than 4KB
        if ([currentFailedRequest lengthOfBytesUsingEncoding:NSUTF8StringEncoding] +
                [currentErrorMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + startLength < 4000)
        {
            failedRequestsString = [currentFailedRequest stringByAppendingString:failedRequestsString];
            errorMessagesString = [currentErrorMessage stringByAppendingString:errorMessagesString];
        }

        // Fill in remaining errors with comma at the end of each error
        for (int i = lastIndex - 1; i >= 0; i--)
        {
            NSString *currentFailedRequest = [NSString stringWithFormat:@"%ld,%@,", self.errorsInfo[i].apiId, self.errorsInfo[i].correlationId];
            NSString *currentErrorMessage = [NSString stringWithFormat:@"%@,", self.errorsInfo[i].error];
            
            NSString *newFailedRequestsString = [currentFailedRequest stringByAppendingString:failedRequestsString];
            NSString *newErrorMessagesString = [currentErrorMessage stringByAppendingString:errorMessagesString];
            
            // Only add next error into string if the resulting string smaller than 4KB, otherwise stop building
            // the string
            if ([newFailedRequestsString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] +
                    [newErrorMessagesString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + startLength < 4000)
            {
                failedRequestsString = newFailedRequestsString;
                errorMessagesString = newErrorMessagesString;
            }
            else
            {
                break;
            }
        }
    }
    NSString *telemetryString = [NSString stringWithFormat:@"%@|%@", failedRequestsString, errorMessagesString];
    return telemetryString;
}

- (NSString *)serializedPlatformFields
{
    if (self.platformFields)
    {
        return [self.platformFields componentsJoinedByString:@","];
    }
    else
    {
        return @"";
    }
}

@end
