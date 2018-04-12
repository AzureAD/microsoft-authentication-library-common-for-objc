//
//  ChallengeHandler.h
//  IdentityCore
//
//  Created by Jason Kim on 4/10/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

typedef void (^ChallengeCompletionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential);

@protocol MSIDChallangeHandler

- (void)handleChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(ChallengeCompletionHandler)completionHandler;

