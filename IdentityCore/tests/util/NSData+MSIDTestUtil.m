//
//  NSData+MSIDTestUtil.m
//  IdentityCore iOS
//
//  Created by Serhii Demcenko on 2019-02-05.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "NSData+MSIDTestUtil.h"

@implementation NSData (MSIDTestUtil)

+ (NSData *)hexStringToData:(NSString *)dataHexString
{
    dataHexString = [dataHexString stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *result = [NSMutableData new];
    unsigned char wholeByte;
    char byteChars[3] = {'\0','\0','\0'};
    int i;
    for (i = 0; i < [dataHexString length] / 2; i++)
    {
        byteChars[0] = [dataHexString characterAtIndex:i * 2];
        byteChars[1] = [dataHexString characterAtIndex:i * 2 + 1];
        wholeByte = strtol(byteChars, NULL, 16);
        [result appendBytes:&wholeByte length:1];
    }
    
    return result;
}

@end
