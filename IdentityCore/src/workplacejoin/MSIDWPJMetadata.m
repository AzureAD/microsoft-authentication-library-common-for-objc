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

#import "MSIDWPJMetadata.h"
#import "MSIDBrokerConstants.h"

NSString *const MSID_DEVICE_INFORMATION_UPN_ID_KEY = @"userPrincipalName";
NSString *const MSID_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY = @"aadDeviceIdentifier";
NSString *const MSID_DEVICE_INFORMATION_AAD_TENANT_ID_KEY = @"aadTenantIdentifier";

@implementation MSIDWPJMetadata

- (NSDictionary *)serializeWithFormat:(BOOL)usePrimaryFormat
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    if (usePrimaryFormat)
    {
        result[MSID_PRIMARY_REGISTRATION_CERTIFICATE_THUMBPRINT] = self.certificateThumbprint;
        result[MSID_PRIMARY_REGISTRATION_CLOUD] = self.cloudHost;
        result[MSID_PRIMARY_REGISTRATION_DEVICE_ID] = self.deviceID;
        result[MSID_PRIMARY_REGISTRATION_TENANT_ID] = self.tenantIdentifier;
        result[MSID_PRIMARY_REGISTRATION_UPN] = self.upn;
    }
    else
    {
        result[MSID_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY] = self.deviceID;
        result[MSID_DEVICE_INFORMATION_UPN_ID_KEY] = self.upn;
        result[MSID_DEVICE_INFORMATION_AAD_TENANT_ID_KEY] = self.tenantIdentifier;
    }
    
    return result;
}

@end
