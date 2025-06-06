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

typedef NSString *const MSIDJwtAlgorithm NS_TYPED_ENUM;
typedef NSString *const MSIDJwtParameterName NS_TYPED_ENUM;

// JWT key constants
extern MSIDJwtParameterName const MSID_JWT_ALG;  // Signing algorithm
extern MSIDJwtParameterName const MSID_JWT_ENC;  // Encryption algorithm
extern MSIDJwtParameterName const MSID_JWT_APV;  // This party's public key for key exchange.

// Asymmetric signature Algorithms values as defined in https://datatracker.ietf.org/doc/html/draft-ietf-jose-json-web-algorithms-36#section-3.1

extern MSIDJwtAlgorithm const MSID_JWT_ALG_RS256;    // RSASSA-PKCS-v1_5 using SHA-256
extern MSIDJwtAlgorithm const MSID_JWT_ALG_ES256;    // ECDSA using P-256 and SHA-256


// Encryption Algorithms
extern MSIDJwtAlgorithm const MSID_JWT_ALG_A256GCM;    // AES GCM using 256-bit key

// Key exchange Algorithms
extern MSIDJwtAlgorithm const MSID_JWT_ALG_ECDH;    // Key Agreement with Elliptic Curve Diffie-Hellman
