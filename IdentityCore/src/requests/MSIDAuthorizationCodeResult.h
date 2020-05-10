//
//  MSIDAuthorizationCodeResult.h
//  IdentityCore
//
//  Created by Olga Dalton on 5/9/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAuthorizationCodeResult : NSObject

@property (nonatomic) NSString *authCode;
@property (nonatomic) NSString *pkceVerifier;
@property (nonatomic) NSString *accountIdentifier;

@end

NS_ASSUME_NONNULL_END
