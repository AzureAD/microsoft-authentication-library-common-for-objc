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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDFakeWPJUtilProvider.h"
#import "MSIDWPJKeyPairWithCert.h"

@implementation MSIDFakeWPJUtilProvider

static NSString *gFakePrimaryEccTenantId = nil;
static MSIDFakeWPJMetadataBlock gFakeMetadataBlock = nil;
static MSIDWPJKeyPairWithCert *gFakeWPJKeys = nil;

+ (NSString *)primaryEccTenantId
{
    return gFakePrimaryEccTenantId;
}

+ (void)setPrimaryEccTenantId:(NSString *)value
{
    gFakePrimaryEccTenantId = [value copy];
}

+ (MSIDFakeWPJMetadataBlock)metadataBlock
{
    return gFakeMetadataBlock;
}

+ (void)setMetadataBlock:(MSIDFakeWPJMetadataBlock)value
{
    gFakeMetadataBlock = [value copy];
}

+ (MSIDWPJKeyPairWithCert *)wpjKeys
{
    return gFakeWPJKeys;
}

+ (void)setWpjKeys:(MSIDWPJKeyPairWithCert *)value
{
    gFakeWPJKeys = value;
}

+ (void)reset
{
    gFakePrimaryEccTenantId = nil;
    gFakeMetadataBlock = nil;
    gFakeWPJKeys = nil;
}

#pragma mark - MSIDWorkPlaceJoinUtilProviding

+ (NSString *)getPrimaryEccTenantWithSharedAccessGroup:(__unused NSString *)sharedAccessGroup
                                               context:(__unused id<MSIDRequestContext>)context
                                                 error:(__unused NSError *__autoreleasing *)error
{
    return gFakePrimaryEccTenantId;
}

+ (MSIDWPJMetadata *)readWPJMetadataWithSharedAccessGroup:(__unused NSString *)sharedAccessGroup
                                         tenantIdentifier:(__unused NSString *)tenantIdentifier
                                               domainName:(__unused NSString *)domainName
                                                  context:(__unused id<MSIDRequestContext>)context
                                                    error:(NSError *__autoreleasing *)error
{
    if (gFakeMetadataBlock)
    {
        return gFakeMetadataBlock(error);
    }
    return nil;
}

+ (MSIDWPJKeyPairWithCert *)getWPJKeysWithTenantId:(__unused NSString *)tenantId
                                           context:(__unused id<MSIDRequestContext>)context
{
    return gFakeWPJKeys;
}

@end
