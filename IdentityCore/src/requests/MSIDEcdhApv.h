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

NS_ASSUME_NONNULL_BEGIN
/// The PartyVInfo for ECDH key agreement (APV)
/// Format for APV: <Prefix length> | <Prefix> | <Public key length> | <Public key> | <Nonce length> | <Nonce>
@interface MSIDEcdhApv : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly) NSString *APV;
@property (nonatomic, readonly) NSData *nonce;
@property (nonatomic, readonly) NSString *apvPrefix;
@property (nonatomic, readonly) SecKeyRef publicKey;

// Format for APV: <Prefix length> | <Prefix> | <Public key length> | <Public key> | <Nonce length> | <Nonce>
- (nullable instancetype)initWithKey:(SecKeyRef)publicKey
                           apvPrefix:(NSString *)prefix
                             context:(id<MSIDRequestContext> _Nullable)context
                               error:(NSError * _Nullable __autoreleasing *)error;

@end
NS_ASSUME_NONNULL_END
