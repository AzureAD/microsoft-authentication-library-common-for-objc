//
//  MSIDJwtAlgorithm.h
//  IdentityCore
//
//  Created by Ameya Patil on 9/24/21.
//  Copyright © 2021 Microsoft. All rights reserved.
//

typedef NSString *const MSIDJwtAlgorithm NS_TYPED_ENUM;
// Algorithms values as defined in https://datatracker.ietf.org/doc/html/draft-ietf-jose-json-web-algorithms-36#section-3.1

extern MSIDJwtAlgorithm const MSID_JWT_ALG_RS256;    // RSASSA-PKCS-v1_5 using SHA-256
extern MSIDJwtAlgorithm const MSID_JWT_ALG_ES256;    // ECDSA using P-256 and SHA-256
extern MSIDJwtAlgorithm const MSID_JWT_ALG_HMAC256;  // HMAC using SHA-256
