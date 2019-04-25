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

#import "MSIDAutomationUserAPIRequestHandler.h"
#import "MSIDTestAutomationConfiguration.h"

@interface MSIDAutomationUserAPIRequestHandler()

@property (nonatomic) NSString *labAPIpath;
@property (nonatomic) NSMutableDictionary *cachedConfigurations;

@end

@implementation MSIDAutomationUserAPIRequestHandler

#pragma mark - Init

- (instancetype)initWithAPIPath:(NSString *)apiPath
           cachedConfigurations:(NSDictionary *)cachedConfigurations
{
    self = [super init];
    
    if (self)
    {
        _labAPIpath = apiPath;
        _cachedConfigurations = [NSMutableDictionary new];
        [_cachedConfigurations addEntriesFromDictionary:cachedConfigurations];
    }
    
    return self;
}

#pragma mark - Execute

- (void)executeAPIRequest:(MSIDAutomationConfigurationRequest *)request
        completionHandler:(void (^)(MSIDTestAutomationConfiguration *result, NSError *error))completionHandler
{
    if (_cachedConfigurations[request])
    {
        if (completionHandler)
        {
            completionHandler(_cachedConfigurations[request], nil);
        }
        
        return;
    }
    
    NSURL *resultURL = [request requestURLWithAPIPath:self.labAPIpath];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:resultURL
                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
      {
          if (error)
          {
              if (completionHandler)
              {
                  completionHandler(nil, error);
              }
              
              return;
          }
          
          MSIDTestAutomationConfiguration *configuration = [[MSIDTestAutomationConfiguration alloc] initWithJSONResponseData:data];
          self.cachedConfigurations[request] = configuration;
          
          if (completionHandler)
          {
              completionHandler(configuration, nil);
          }
          
      }] resume];
}

@end
