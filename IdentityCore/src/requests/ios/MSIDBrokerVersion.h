//
//  MSIDBrokerVersion.h
//  IdentityCore iOS
//
//  Created by Olga Dalton on 8/1/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MSIDBrokerVersionType)
{
    MSIDBrokerVersionTypeWithADALOnly, // First broker version supporting ADAL only
    MSIDBrokerVersionTypeWithV2Support, // Second broker version supporting both ADAL and MSAL
    MSIDBrokerVersionTypeWithUniversalLinkSupport, // Third broker version supporting universal links and new secure broker protocol
    
    MSIDBrokerVersionTypeDefault = MSIDBrokerVersionTypeWithUniversalLinkSupport
};

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerVersion : NSObject

@property (nonatomic, readonly) MSIDBrokerVersionType versionType;
@property (nonatomic, readonly) BOOL isPresentOnDevice;
@property (nonatomic, readonly) NSString *brokerBaseUrlString;

- (nullable instancetype)initWithVersionType:(MSIDBrokerVersionType)versionType;

@end

NS_ASSUME_NONNULL_END
