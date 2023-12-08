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

#import <Foundation/Foundation.h>

@interface MSIDTestURLResponse : NSObject
{
@public
    NSURL *_requestURL;
    id _requestJSONBody;
    id _requestParamsBody;
    NSMutableDictionary *_requestHeaders;
    NSData *_requestBody;
    NSDictionary *_QPs;
    NSDictionary *_expectedRequestHeaders;
    NSData *_responseData;
    NSURLResponse *_response;
    NSError *_error;
    dispatch_semaphore_t _waitSemaphore;
}

+ (NSDictionary *)defaultHeaders;

+ (instancetype)requestURLString:(NSString *)requestUrlString
               responseURLString:(NSString *)responseUrlString
                    responseCode:(NSInteger)responseCode
                httpHeaderFields:(NSDictionary *)headerFields
                dictionaryAsJSON:(NSDictionary *)data;

+ (instancetype)requestURLString:(NSString *)requestUrlString
                 requestJSONBody:(id)requestJSONBody
               responseURLString:(NSString *)responseUrlString
                    responseCode:(NSInteger)responseCode
                httpHeaderFields:(NSDictionary *)headerFields
                dictionaryAsJSON:(NSDictionary *)data;

+ (instancetype)requestURLString:(NSString *)requestUrlString
                  requestHeaders:(NSDictionary *)requestHeaders
               requestParamsBody:(id)requestParams
               responseURLString:(NSString *)responseUrlString
                    responseCode:(NSInteger)responseCode
                httpHeaderFields:(NSDictionary *)headerFields
                dictionaryAsJSON:(NSDictionary *)data;

+ (instancetype)request:(NSURL *)request
               response:(NSURLResponse *)response
            reponseData:(NSData *)data;

+ (instancetype)request:(NSURL *)request
                reponse:(NSURLResponse *)response;

+ (instancetype)request:(NSURL *)request
       respondWithError:(NSError *)error;

+ (instancetype)serverNotFoundResponseForURLString:(NSString *)requestURLString;

- (void)setRequestURL:(NSURL *)requestURL;
- (void)setRequestHeaders:(NSDictionary *)headers;
- (void)setRequestBody:(NSData *)body;
- (void)setUrlFormEncodedBody:(NSDictionary *)formParameters;

- (void)setResponseURL:(NSString *)urlString
                  code:(NSInteger)code
          headerFields:(NSDictionary *)headerFields;
- (void)setResponseJSON:(id)jsonResponse;
- (void)setResponseData:(NSData *)response;

/*!
    Set a semaphore that MSIDTestURLSession will wait on until it is signalled in the test. The test
    must signal this semaphore or else the test will deadlock.
 */
- (void)setWaitSemaphore:(dispatch_semaphore_t)sem;

- (BOOL)matchesURL:(NSURL *)url
           headers:(NSDictionary *)headers
              body:(NSData *)body;
- (BOOL)matchesURL:(NSURL *)url;
- (BOOL)matchesBody:(NSData *)body;
- (BOOL)matchesHeaders:(NSDictionary *)headers;
- (void)setError:(NSError *)error;

@end
