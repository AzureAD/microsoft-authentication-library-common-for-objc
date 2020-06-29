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

#import "MSIDTestURLResponse.h"
#import "MSIDDeviceId.h"

#import "NSDictionary+MSIDExtensions.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "NSURL+MSIDExtensions.h"
#import "NSURL+MSIDTestUtil.h"
#import "NSString+MSIDExtensions.h"

@implementation MSIDTestURLResponse

+ (NSDictionary *)defaultHeaders
{
    static NSDictionary *s_defaultHeaders = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        NSMutableDictionary* headers = [[MSIDDeviceId deviceId] mutableCopy];
        
        headers[@"Accept"] = @"application/json";
        headers[@"client-request-id"] = [MSIDTestRequireValueSentinel sentinel];
        headers[@"return-client-request-id"] = @"true";
        headers[@"x-app-name"] = @"UnitTestHost";
        headers[@"x-app-ver"] = @"1.0";
        
        headers[@"x-ms-PkeyAuth"] = @"1.0";
        
        // TODO: This really shouldn't be a default header...
        headers[@"Content-Type"] = @"application/x-www-form-urlencoded";
        
        s_defaultHeaders = [headers copy];
    });
    
    return s_defaultHeaders;
}

+ (MSIDTestURLResponse *)request:(NSURL *)request
               requestJSONBody:(NSDictionary *)requestBody
                      response:(NSURLResponse *)urlResponse
                   reponseData:(NSData *)data
{
    MSIDTestURLResponse * response = [MSIDTestURLResponse new];
    [response setRequestURL:request];
    response->_requestJSONBody = requestBody;
    response->_response = urlResponse;
    response->_responseData = data;
    [response setRequestHeaders:nil];
    
    return response;
}

+ (MSIDTestURLResponse *)request:(NSURL *)request
                      response:(NSURLResponse *)urlResponse
                   reponseData:(NSData *)data
{
    MSIDTestURLResponse * response = [MSIDTestURLResponse new];
    
    [response setRequestURL:request];
    response->_response = urlResponse;
    response->_responseData = data;
    [response setRequestHeaders:nil];
    
    return response;
}

+ (MSIDTestURLResponse *)request:(NSURL *)request
                       reponse:(NSURLResponse *)urlResponse
{
    MSIDTestURLResponse * response = [MSIDTestURLResponse new];
    
    [response setRequestURL:request];
    response->_response = urlResponse;
    [response setRequestHeaders:nil];
    
    return response;
}

+ (MSIDTestURLResponse *)request:(NSURL *)request
              respondWithError:(NSError *)error
{
    MSIDTestURLResponse * response = [MSIDTestURLResponse new];
    
    [response setRequestURL:request];
    [response setRequestHeaders:[MSIDDeviceId deviceId]];
    response->_error = error;
    
    return response;
}

+ (MSIDTestURLResponse *)serverNotFoundResponseForURLString:(NSString *)requestURLString
{
    NSURL *requestURL = [NSURL URLWithString:requestURLString];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestURL
                                            respondWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                                 code:NSURLErrorCannotFindHost
                                                                             userInfo:nil]];
    return response;
}

+ (MSIDTestURLResponse *)requestURLString:(NSString*)requestUrlString
                      responseURLString:(NSString*)responseUrlString
                           responseCode:(NSInteger)responseCode
                       httpHeaderFields:(NSDictionary *)headerFields
                       dictionaryAsJSON:(NSDictionary *)data
{
    MSIDTestURLResponse *response = [MSIDTestURLResponse new];
    [response setRequestURL:[NSURL URLWithString:requestUrlString]];
    [response setResponseURL:responseUrlString code:responseCode headerFields:headerFields];
    [response setRequestHeaders:[MSIDDeviceId deviceId]];
    [response setJSONResponse:data];
    
    return response;
}

+ (MSIDTestURLResponse *)requestURLString:(NSString*)requestUrlString
                        requestJSONBody:(id)requestJSONBody
                      responseURLString:(NSString*)responseUrlString
                           responseCode:(NSInteger)responseCode
                       httpHeaderFields:(NSDictionary *)headerFields
                       dictionaryAsJSON:(NSDictionary *)data
{
    MSIDTestURLResponse *response = [MSIDTestURLResponse new];
    [response setRequestURL:[NSURL URLWithString:requestUrlString]];
    [response setResponseURL:responseUrlString code:responseCode headerFields:headerFields];
    response->_requestJSONBody = requestJSONBody;
    [response setJSONResponse:data];
    
    return response;
}

+ (MSIDTestURLResponse *)requestURLString:(NSString*)requestUrlString
                         requestHeaders:(NSDictionary *)requestHeaders
                      requestParamsBody:(id)requestParams
                      responseURLString:(NSString*)responseUrlString
                           responseCode:(NSInteger)responseCode
                       httpHeaderFields:(NSDictionary *)headerFields
                       dictionaryAsJSON:(NSDictionary *)data
{
    MSIDTestURLResponse *response = [MSIDTestURLResponse new];
    [response setRequestURL:[NSURL URLWithString:requestUrlString]];
    [response setResponseURL:responseUrlString code:responseCode headerFields:headerFields];
    [response setRequestHeaders:requestHeaders];
    [response setUrlFormEncodedBody:requestParams];
    [response setJSONResponse:data];
    
    return response;
}

- (void)setResponseURL:(NSString *)urlString
                  code:(NSInteger)code
          headerFields:(NSDictionary *)headerFields
{
    NSHTTPURLResponse * response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:urlString]
                                                               statusCode:code
                                                              HTTPVersion:@"1.1"
                                                             headerFields:headerFields];
    
    _response = response;
}

- (void)setResponseJSON:(id)jsonResponse
{
    [self setJSONResponse:jsonResponse];
}

- (void)setJSONResponse:(id)jsonResponse
{
    if (!jsonResponse)
    {
        _responseData = nil;
        return;
    }
    
    NSError *error = nil;
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:jsonResponse options:0 error:&error];
    _responseData = responseData;
    
    NSAssert(_responseData, @"Invalid JSON object set for test response! %@", error);
}

- (void)setResponseData:(NSData *)response
{
    _responseData = response;
}

- (void)setRequestURL:(NSURL *)requestURL
{
    
    _requestURL = requestURL;
    NSString *query = [requestURL query];
    _QPs = [NSString msidIsStringNilOrBlank:query] ? nil : [NSDictionary msidDictionaryFromWWWFormURLEncodedString:query];
}

- (void)setRequestHeaders:(NSDictionary *)headers
{
    if (headers)
    {
        _requestHeaders = [headers mutableCopy];
    }
    else
    {
        _requestHeaders = [NSMutableDictionary new];
    }
    
    // These values come from ADClientMetrics and are dependent on a previous request, which breaks
    // the isolation of the tests. For now the easiest path is to ignore them entirely.
    if (!_requestHeaders[@"x-client-last-endpoint"])
    {
        _requestHeaders[@"x-client-last-error"] = [MSIDTestIgnoreSentinel sentinel];
        _requestHeaders[@"x-client-last-endpoint"] = [MSIDTestIgnoreSentinel sentinel];
        _requestHeaders[@"x-client-last-request"] = [MSIDTestIgnoreSentinel sentinel];
        _requestHeaders[@"x-client-last-response-time"] = [MSIDTestIgnoreSentinel sentinel];
    }
}

- (void)setRequestBody:(NSData *)body
{
    _requestBody = body;
}

- (void)setUrlFormEncodedBody:(NSDictionary *)formParameters
{
    _requestParamsBody = nil;
    if (!formParameters)
    {
        return;
    }
    
    _requestParamsBody = formParameters;
    if (!_requestHeaders)
    {
        _requestHeaders = [NSMutableDictionary new];
    }
    
    _requestHeaders[@"Content-Type"] = @"application/x-www-form-urlencoded";
}

- (void)setWaitSemaphore:(dispatch_semaphore_t)sem
{
    _waitSemaphore = sem;
}

- (BOOL)matchesURL:(NSURL *)url
           headers:(NSDictionary *)headers
              body:(NSData *)body
{
    // We don't want the compiler to short circuit this out so that ways we print out all of the
    // things in the response that doesn't match.
    BOOL ret = YES;
    ret = [self matchesURL:url] ? ret : NO;
    ret = [self matchesHeaders:headers] ? ret : NO;
    ret = [self matchesBody:body] ? ret : NO;
    return ret;
}

- (BOOL)matchesURL:(NSURL *)url
{
    return [_requestURL matchesURL:url];
}

- (BOOL)matchesBody:(NSData *)body
{
    if (_requestJSONBody)    {
        NSError* error = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingAllowFragments error:&error];
        BOOL match = [obj isEqual:_requestJSONBody];
        return match;
    }
    
    if (_requestParamsBody)
    {
        NSString * string = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        NSDictionary *obj = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:string];
        return [_requestParamsBody compareAndPrintDiff:obj dictionaryDescription:@"URL Encoded Body Parameters"];
    }
    
    if (_requestBody)
    {
        return [_requestBody isEqualToData:body];
    }
    
    return YES;
}

- (BOOL)matchesHeaders:(NSDictionary *)headers
{
    if (!_requestHeaders)
    {
        if (!headers || headers.count == 0)
        {
            return YES;
        }
        // This wiil spit out to console the extra stuff that we weren't expecting
        [@{} compareAndPrintDiff:headers dictionaryDescription:@"Request Headers"];
        return NO;
    }
    
    return [_requestHeaders compareAndPrintDiff:headers dictionaryDescription:@"Request Headers"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass(self.class), _requestURL];
}

@end
