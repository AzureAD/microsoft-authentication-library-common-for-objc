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

#import <Foundation/Foundation.h>

@interface MSIDRequestTelemetryUtils : NSObject

/*! returns string based on provided bool value
 @param val bool value
 @return string based on provided bool value
 */
+ (nonnull NSString *)getStringFromBool:(BOOL)val;

/*! adds signout application identifier value in user defaults for telemetry
 @param applicationIdentifier signout app identifier value
 */
+ (BOOL)writeSignoutApplicationForTelemetry:(nonnull NSString *)applicationIdentifier
                                      error:(NSError * _Nullable * _Nullable)error;

/*! returns signout application identifier value from user defaults for telemetry
 @return signout application identifier string
 */
+ (nullable NSString *)readSignoutApplicationForTelemetry;

/*! removes signout application identifier value from user defaults for telemetry
 */
+ (void)removeSignoutApplicationForTelemetry;

/*! returns current request telemetry platform fields for shared device
 @param registrationType work place join registration user type information
 @param registrationSource work place join registration application source information
 @param signinApplication signin application identifier
 @param signoutApplication signout application idetifier
 @return array with current request telemetry platform fields for shared device
 */
+ (nonnull NSMutableArray<NSString *> *) getTelemetryPlatformFieldsForSharedDevice:(nullable NSString *)registrationType
                                                                registrationSource:(nullable NSString *)registrationSource
                                                                 signinApplication:(nullable NSString *)signinApplication
                                                                signoutApplication:(nullable NSString *)signoutApplication;

/*! returns current request telemetry platform fields for multiple registrations
 @param registrationNumber number of work place join registrations on a given physical device
 @param cloudNumber number of different clouds that a device is registered to on a given physical device
 @param registrationSequenceNumber number of times user has registered a given physical device since its last reset for the given tenant.
 @param requestPurpose server request purpose
 @param registrationSource workplace join registration source application information
 @return array with current request telemetry platform fields for multiple registrations
 */
+ (nonnull NSMutableArray<NSString *> *) getTelemetryPlatformFieldsForMultipleRegistrations:(nullable NSNumber *)registrationNumber
                                                                                cloudNumber:(nullable NSNumber *)cloudNumber
                                                                 registrationSequenceNumber:(nullable NSNumber *)registrationSequenceNumber
                                                                             requestPurpose:(nullable NSString *)requestPurpose
                                                                         registrationSource:(nullable NSString *)registrationSource;
@end
