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

#include "MSIDSymmetricKeyAbstraction.h"
//@protocol MSIDSymmetricKeyProtocol
//
//- (NSString *) getDummyString;
//- (NSData *) symmetericKeyBytes;
//
//@end

@implementation MSIDSymmetricKeyAbstraction

- (nullable instancetype)initWithSymmetericKeyBytes:(NSData *)symmetericKeyInBytes {
    if (!symmetericKeyInBytes)
    {
        return nil;
    }
    
    self = [super init];
    
    if (self)
    {
        _symmetericKeyImplementation = [MSIDSymmetericKeyImplementation createWithSymmetericKeyInBytes:symmetericKeyInBytes];
    }
    
    return self;
}

- (nullable NSString *)createVerifySignature:(NSData *)context
                                  dataToSign:(NSString *)dataToSign {
    if (_symmetericKeyImplementation == nil) {
        return nil;
    }
    
    return [_symmetericKeyImplementation createVerifySignatureWithContext:context dataToSign:dataToSign];
}

- (nullable NSString *)decryptUsingAuthenticatedAes:(NSData *)cipherText
                                       contextBytes:(NSData *)contextBytes
                                                 iv:(NSData *)iv
                                  authenticationTag:(NSData *)authenticationTag
                                 authenticationData:(NSData *)authenticationData {
    if (_symmetericKeyImplementation == nil) {
        return nil;
    }
    
    return [_symmetericKeyImplementation decryptUsingAuthenticatedAesWithCipherText:cipherText contextBytes:contextBytes iv:iv authenticationTag:authenticationTag authenticationData:authenticationData];
}

- (nullable NSData *)encryptUsingAuthenticatedAesForTest:(NSData *)message
                                              contextBytes:(NSData *)contextBytes
                                                        iv:(NSData *)iv
                                         authenticationTag:(NSData *)authenticationTag
                                        authenticationData:(NSData *)authenticationData {
    if (_symmetericKeyImplementation == nil) {
        return nil;
    }
    
    return [_symmetericKeyImplementation encryptUsingAuthenticatedAesForTestWithMessage:message contextBytes:contextBytes iv:iv authenticationTag:authenticationTag authenticationData:authenticationData];
}

- (nonnull NSString *)getRaw {
    if (_symmetericKeyImplementation == nil) {
        return nil;
    }
    
    return [_symmetericKeyImplementation getRaw];
}

@end
