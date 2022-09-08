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


#import "MSIDRequestTelemetryUtils.h"
#import "MSIDRequestTelemetryConstants.h"

@implementation MSIDRequestTelemetryUtils

+ (nonnull NSString *)getStringFromBool:(BOOL)val
{
    if (val)
    {
        return MSID_REQUEST_TELEMETRY_SCHEMA_STRING_TRUE;
    }
    
    return MSID_REQUEST_TELEMETRY_SCHEMA_STRING_FALSE;
}

+ (BOOL)writeSignoutApplicationForTelemetry:(nonnull NSString *)applicationIdentifier
                                      error:(NSError * _Nullable * _Nullable)error
{
    if (![applicationIdentifier isKindOfClass:[NSString class]])
    {
        NSString *errorDescription = @"Signout application identifier is nil or empty";
        NSError *validationError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
        if (error)
        {
            *error = validationError;
        }
        
        return NO;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:applicationIdentifier forKey:MSID_CURRENT_REQUEST_TELEMETRY_KEY_FLW_SIGNOUT_APP];
    return YES;
}

+ (nullable NSString *)readSignoutApplicationForTelemetry
{
   return [[NSUserDefaults standardUserDefaults] stringForKey:MSID_CURRENT_REQUEST_TELEMETRY_KEY_FLW_SIGNOUT_APP];
}

+ (void)removeSignoutApplicationForTelemetry
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MSID_CURRENT_REQUEST_TELEMETRY_KEY_FLW_SIGNOUT_APP];
}

+ (nonnull NSMutableArray<NSString *> *) getTelemetryPlatformFieldsForSharedDevice:(nullable NSString *)registrationType
                                                                registrationSource:(nullable NSString *)registrationSource
                                                                 signinApplication:(nullable NSString *)signinApplication
                                                                signoutApplication:(nullable NSString *)signoutApplication
{
    NSMutableArray<NSString *> *platformFields = [NSMutableArray<NSString *> new];
    [platformFields addObject:MSID_REQUEST_TELEMETRY_SCHEMA_STRING_TRUE];
    [platformFields addObject:registrationType ? registrationType : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    [platformFields addObject:registrationSource ? registrationSource : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    [platformFields addObject:signinApplication ? signinApplication : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    [platformFields addObject:signoutApplication ? signoutApplication : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    return platformFields;
}

+ (nonnull NSMutableArray<NSString *> *) getTelemetryPlatformFieldsForMultipleRegistrations:(nullable NSNumber *)registrationNumber
                                                                                cloudNumber:(nullable NSNumber *)cloudNumber
                                                                 registrationSequenceNumber:(nullable NSNumber *)registrationSequenceNumber
                                                                             requestPurpose:(nullable NSString *)requestPurpose
                                                                         registrationSource:(nullable NSString *)registrationSource
{
    NSMutableArray<NSString *> *platformFields = [NSMutableArray<NSString *> new];
    [platformFields addObject:MSID_REQUEST_TELEMETRY_SCHEMA_STRING_FALSE];
    [platformFields addObject:registrationNumber ? [registrationNumber stringValue] : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    [platformFields addObject:cloudNumber ? [cloudNumber stringValue] : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    [platformFields addObject:registrationSequenceNumber ? [registrationSequenceNumber stringValue] : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    [platformFields addObject:requestPurpose ? requestPurpose : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    [platformFields addObject:registrationSource ? registrationSource : MSID_REQUEST_TELEMETRY_SCHEMA_STRING_EMPTY];
    return platformFields;
}

@end
