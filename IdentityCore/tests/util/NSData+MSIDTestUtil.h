//
//  NSData+MSIDTestUtil.h
//  IdentityCore iOS
//
//  Created by Serhii Demcenko on 2019-02-05.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (MSIDTestUtil)

+ (NSData *)hexStringToData:(NSString *)dataHexString;

@end

NS_ASSUME_NONNULL_END
