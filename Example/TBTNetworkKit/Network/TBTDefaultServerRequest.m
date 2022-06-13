//
//  TBTDefaultServerRequest.m
//  TBT
//
//  Created by 刘冉 on 2022/6/11.
//

#import "TBTDefaultServerRequest.h"

@implementation TBTDefaultServerRequest

- (instancetype)init {
    if (self = [super init]) {
        self.baseURI = @"http://v.juhe.cn/";
        [self.cacheHandler setShouldCacheBlock:^BOOL(TBTNetworkResponse * _Nonnull response) {
            return YES;
        }];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%s",__func__);
}

#pragma mark - override
- (AFHTTPRequestSerializer *)requestSerializer {
    AFHTTPRequestSerializer *serializer = [[AFHTTPRequestSerializer alloc] init];
    serializer.timeoutInterval = 20;
    return serializer;
}

- (AFHTTPResponseSerializer *)responseSerializer {
    AFHTTPResponseSerializer *serializer = [[AFHTTPResponseSerializer alloc] init];
    NSMutableSet *types = [NSMutableSet set];
    [types addObject:@"text/html"];
    [types addObject:@"text/plain"];
    [types addObject:@"application/json"];
    [types addObject:@"text/json"];
    [types addObject:@"text/javascript"];
    serializer.acceptableContentTypes = types;
    return serializer;
}

- (void)start {
    NSLog(@"开始网络请求\n %@",self.requestIdentifier);
    [super start];
}

- (void)tbt_preprocessSuccessInChildThreadWithResponse:(TBTNetworkResponse *)response {
    NSData *objData = (NSData *)response.responseObject;
    if (!objData.length) {
        return;
    }
    NSError *jsonError = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:objData options:NSJSONReadingMutableContainers error:&jsonError];
    if (jsonError) {
        NSLog(@"json 解析失败 %@",jsonError);
        return;
    }
    if (![dict.allKeys containsObject:@"result"]) {
        return;
    }
    response.responseObject = [dict objectForKey:@"result"];
    NSLog(@"%@",response.responseObject);
}

@end
