//
//  TBTNetworkResponse.m
//  TBT
//
//  Created by 刘冉 on 2022/6/10.
//

#import "TBTNetworkResponse.h"

@implementation TBTNetworkResponse

+ (instancetype)responseWithSessionTask:(NSURLSessionTask *)sessionTask responseObject:(id)responseObject error:(NSError *)error {
    TBTNetworkResponse *response = [[TBTNetworkResponse alloc] init];
    response->_sessionTask = sessionTask;
    response->_responseObject = responseObject;
    response->_error = error;
    return response;
}

#pragma mark - getter
- (NSHTTPURLResponse *)URLResponse {
    if (!self.sessionTask || ![self.sessionTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
        return nil;
    }
    return (NSHTTPURLResponse *)self.sessionTask.response;
}

- (void)dealloc {
    NSLog(@"%s",__func__);
}

@end
