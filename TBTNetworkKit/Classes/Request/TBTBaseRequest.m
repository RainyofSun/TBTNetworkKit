//
//  TBTBaseRequest.m
//  TBT
//
//  Created by 刘冉 on 2022/6/10.
//

#import "TBTBaseRequest.h"
#import "TBTNetworkManager.h"
#import "TBTBaseRequest+TBTInternal.h"
#import "TBTNetworkCache+TBTInternal.h"
#import <pthread/pthread.h>

#define TBTN_IDECORD_LOCK(...) \
pthread_mutex_lock(&self->_lock); \
__VA_ARGS__ \
pthread_mutex_unlock(&self->_lock);

@interface TBTBaseRequest ()
{
    pthread_mutex_t _lock;
}
@property (nonatomic,copy,nullable) TBTRequestProgressBlock uploadProgress;
@property (nonatomic,copy,nullable) TBTRequestProgressBlock downloadProgress;
@property (nonatomic,copy,nullable) TBTRequestCacheBlock    cacheBlock;
@property (nonatomic,copy,nullable) TBTRequestSuccessBlock  successBlock;
@property (nonatomic,copy,nullable) TBTRequestFailureBlock  failureBlock;
@property (nonatomic,strong) TBTNetworkCache *cacheHandler;
// 记录网络任务标识容器
@property (nonatomic,strong) NSMutableSet <NSNumber *>*taskIDRecord;

@end

@implementation TBTBaseRequest

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&_lock, NULL);
        self.releaseStrategy = TBTNetworkReleaseStrategy_HoldRequest;
        self.repeatStrategy = TBTNetworkRepeatStrategy_AllAllowed;
        self.taskIDRecord = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc {
    if (self.releaseStrategy == TBTNetworkReleaseStrategy_WhenRequestDealloc) {
        [self cancel];
    }
    pthread_mutex_destroy(&_lock);
    NSLog(@"%s",__func__);
}

#pragma mark - Public methods
- (void)startWithSuccess:(TBTRequestSuccessBlock)success failure:(TBTRequestFailureBlock)failure {
    [self startWithUploadProgress:nil downloadProgress:nil cache:nil success:success failure:failure];
}

- (void)startWithCache:(TBTRequestCacheBlock)cache success:(TBTRequestSuccessBlock)success failure:(TBTRequestFailureBlock)failure {
    [self startWithUploadProgress:nil downloadProgress:nil cache:cache success:success failure:failure];
}

- (void)startWithUploadProgress:(TBTRequestProgressBlock)uploadProgress downloadProgress:(TBTRequestProgressBlock)downloadProgress cache:(TBTRequestCacheBlock)cache success:(TBTRequestSuccessBlock)success failure:(TBTRequestFailureBlock)failure {
    self.uploadProgress = uploadProgress;
    self.downloadProgress = downloadProgress;
    self.cacheBlock = cache;
    self.successBlock = success;
    self.failureBlock = failure;
    [self start];
}

- (void)start {
    if (self.isExecuting) {
        switch (self.repeatStrategy) {
            case TBTNetworkRepeatStrategy_CancelNewest:
                return;
            case TBTNetworkRepeatStrategy_CancelOldest:
                [self cancelNetworking];
                break;
            default:
                break;
        }
    }
    
    NSString *cacheKey = [self requestCacheKey];
    if (self.cacheHandler.readMode == TBTNetworkCacheReadMode_None) {
        [self startWithCacheKey:cacheKey];
        return;
    }
    
    // 读取缓存
    [self.cacheHandler objectForKey:cacheKey withBlock:^(NSString * _Nonnull key, id<NSCoding>  _Nullable object) {
        if (object) {
            // 缓存命中
            TBTNetworkResponse *response = [TBTNetworkResponse responseWithSessionTask:nil responseObject:object error:nil];
            [self successWithResponse:response cacheKey:cacheKey fromCache:YES taskID:nil];
        }
        
        BOOL needRequestNetwork = !object || self.cacheHandler.readMode == TBTNetworkCacheReadMode_SendNetwork;
        if (needRequestNetwork) {
            [self startWithCacheKey:cacheKey];
        } else {
            [self clearRequestBlocks];
        }
    }];
}

- (void)cancel {
    self.delegate = nil;
    [self clearRequestBlocks];
    [self cancelNetworking];
}

- (void)cancelNetworking {
    // 取消队列中的网络请求
    TBTN_IDECORD_LOCK(
                      NSSet *removeSet = self.taskIDRecord.mutableCopy;
                      [self.taskIDRecord removeAllObjects];
                      );
    // 移除可能已经发出的或者正要发出网络请求
    [[TBTNetworkManager sharedManager] cancelNetworkingWithSet:removeSet];
}

- (BOOL)isExecuting {
    TBTN_IDECORD_LOCK(BOOL isExecuting = self.taskIDRecord.count > 0;);
    return isExecuting;
}

- (void)clearRequestBlocks {
    self.uploadProgress = nil;
    self.downloadProgress = nil;
    self.cacheBlock = nil;
    self.successBlock = nil;
    self.failureBlock = nil;
}

#pragma mark - Request
- (void)startWithCacheKey:(NSString *)cacheKey {
    __weak typeof(self) weakSelf = self;
    BOOL(^cancelled)(NSNumber *) = ^BOOL(NSNumber *taskID) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return YES;
        }
        TBTN_IDECORD_LOCK(BOOL contains = [self.taskIDRecord containsObject:taskID];);
        return !contains;
    };
    
    __block NSNumber *taskID = nil;
    if (self.releaseStrategy == TBTNetworkReleaseStrategy_HoldRequest) {
        taskID = [[TBTNetworkManager sharedManager] startNetworkingWithRequest:self uploadProgress:^(NSProgress *progress) {
            if (cancelled(taskID)) {
                return;
            }
            [self requestUploadWithProgress:progress];
        } downloadProgress:^(NSProgress *progress) {
            if (cancelled(taskID)) {
                return;
            }
            [self requestDownloadWithProgress:progress];
        } completion:^(TBTNetworkResponse * _Nonnull response) {
            if (cancelled(taskID)) {
                return;
            }
            [self requestCompletionWithResponse:response cacheKey:cacheKey fromCache:NO taskID:taskID];
        }];
    } else {
        __weak typeof(self) weakSelf = self;
        taskID = [[TBTNetworkManager sharedManager] startNetworkingWithRequest:weakSelf uploadProgress:^(NSProgress *progress) {
            if (cancelled(taskID)) {
                return;
            }
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf requestUploadWithProgress:progress];
        } downloadProgress:^(NSProgress *progress) {
            if (cancelled(taskID)) {
                return;
            }
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf requestDownloadWithProgress:progress];
        } completion:^(TBTNetworkResponse * _Nonnull response) {
            if (cancelled(taskID)) {
                return;
            }
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf requestCompletionWithResponse:response cacheKey:cacheKey fromCache:NO taskID:taskID];
        }];
    }
    
    if (nil != taskID) {
        TBTN_IDECORD_LOCK([self.taskIDRecord addObject:taskID];);
    }
}

#pragma mark - Response
- (void)requestUploadWithProgress:(NSProgress *)progress {
    TBTNETWORK_MAIN_QUEUE_ASYNC(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(requestUploadWithProgress:)]) {
            [self.delegate request:self uploadProgress:progress];
        }
        if (self.uploadProgress) {
            self.uploadProgress(progress);
        }
    });
}

- (void)requestDownloadWithProgress:(NSProgress *)progress {
    TBTNETWORK_MAIN_QUEUE_ASYNC(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(requestDownloadWithProgress:)]) {
            [self.delegate request:self downloadProgress:progress];
        }
        if (self.downloadProgress) {
            self.downloadProgress(progress);
        }
    });
}

- (void)requestCompletionWithResponse:(TBTNetworkResponse *)response cacheKey:(NSString *)cacheKey fromCache:(BOOL)fromCache taskID:(NSNumber *)taskID {
    __weak typeof(self) weakSelf = self;
    void(^progress)(TBTRequestRedirection) = ^(TBTRequestRedirection redirection) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        switch (redirection) {
            case TBTRequestRedirection_Success:
                [strongSelf successWithResponse:response cacheKey:cacheKey fromCache:NO taskID:taskID];
                break;
            case TBTRequestRedirection_Failure:
                [strongSelf failureWithResponse:response taskID:taskID];
                break;
            case TBTRequestRedirection_Stop:
            default:
                TBTN_IDECORD_LOCK([self.taskIDRecord removeObject:taskID];);
                break;
        }
    };
    
    if ([self respondsToSelector:@selector(tbt_redirection:response:)]) {
        [self tbt_redirection:progress response:response];
    } else {
        TBTRequestRedirection redirection = response.error ? TBTRequestRedirection_Failure : TBTRequestRedirection_Success;
        progress(redirection);
    }
}

- (void)successWithResponse:(TBTNetworkResponse *)response cacheKey:(NSString *)cacheKey fromCache:(BOOL)fromCache taskID:(NSNumber *)taskID {
    if ([self respondsToSelector:@selector(tbt_preprocessSuccessInChildThreadWithResponse:)]) {
        [self tbt_preprocessSuccessInChildThreadWithResponse:response];
    }
    TBTNETWORK_MAIN_QUEUE_ASYNC(^{
        if ([self respondsToSelector:@selector(tbt_preprocessSuccessInMainThreadWithResponse:)]) {
            [self tbt_preprocessSuccessInMainThreadWithResponse:response];
        }
        
        if (fromCache) {
            if ([self.delegate respondsToSelector:@selector(request:cacheWithResponse:)]) {
                [self.delegate request:self cacheWithResponse:response];
            }
            if (self.cacheBlock) {
                self.cacheBlock(response);
            }
        } else {
            if ([self.delegate respondsToSelector:@selector(request:successWithResponse:)]) {
                [self.delegate request:self successWithResponse:response];
            }
            if (self.successBlock) {
                self.successBlock(response);
            }
            [self clearRequestBlocks];
            
            // 在网络响应数据被业务处理完成后进行缓存，可避免将异常数据写入缓存（比如数据导致 Crash 的情况）
            BOOL shouldCache = !self.cacheHandler.shouldCacheBlock || self.cacheHandler.shouldCacheBlock(response);
            BOOL isSendFile = self.requestConstructingBody || self.downloadPath.length > 0;
            if (!isSendFile && shouldCache) {
                [self.cacheHandler setObject:response.responseObject forKey:cacheKey];
            }
        }
        
        if (taskID) {
            [self.taskIDRecord removeObject:taskID];
        }
    });
}

- (void)failureWithResponse:(TBTNetworkResponse *)response taskID:(NSNumber *)taskID {
    if ([self respondsToSelector:@selector(tbt_preprocessFailureInChildThreadWithResponse:)]) {
        [self tbt_preprocessFailureInChildThreadWithResponse:response];
    }
    TBTNETWORK_MAIN_QUEUE_ASYNC(^{
        if ([self respondsToSelector:@selector(tbt_preprocessFailureInMainThreadWithResponse:)]) {
            [self tbt_preprocessFailureInMainThreadWithResponse:response];
        }
        if ([self.delegate respondsToSelector:@selector(request:failureWithResponse:)]) {
            [self.delegate request:self failureWithResponse:response];
        }
        if (self.failureBlock) {
            self.failureBlock(response);
        }
        [self clearRequestBlocks];
        if (taskID) {
            [self.taskIDRecord removeObject:taskID];
        }
    });
}

#pragma mark - private methods
- (NSString *)requestCacheKey {
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@",self.cacheHandler.extraCacheKey,[self requestIdentifier]];
    if (self.cacheHandler.customCacheKeyBlock) {
        cacheKey = self.cacheHandler.customCacheKeyBlock(cacheKey);
    }
    return cacheKey;
}

- (NSString *)requestIdentifier {
    NSString *identifier = [NSString stringWithFormat:@"%@-%@%@",[self requestMethodString],[self validRequestURLString],[self stringFromParameter:[self validRequestParameter]]];
    return identifier;
}

- (NSString *)stringFromParameter:(NSDictionary *)parameter {
    NSMutableString *string = [NSMutableString string];
    NSArray *keys = [parameter.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [[NSString stringWithFormat:@"%@",obj1] compare:[NSString stringWithFormat:@"%@",obj2] options:NSLiteralSearch];
    }];
    for (id key in keys) {
        [string appendString:[NSString stringWithFormat:@"%@%@=%@",string.length > 0 ? @"&" : @"?",key,parameter[key]]];
    }
    return string;
}
    
#pragma mark - Category
- (NSString *)requestMethodString {
    switch (self.requestMethod) {
        case TBTRequestMethod_GET:
            return @"GET";
        case TBTRequestMethod_POST:
            return @"POST";
        case TBTRequestMethod_PUT:
            return @"PUT";
        case TBTRequestMethod_HEAD:
            return @"HEAD";
        case TBTRequestMethod_PATCH:
            return @"PATCH";
        case TBTRequestMethod_DELETE:
            return @"DELETE";
    }
}

- (NSString *)validRequestURLString {
    NSURL *baseURL = [NSURL URLWithString:self.baseURI];
    NSString *URLString = [NSURL URLWithString:self.requestURI relativeToURL:baseURL].absoluteString;
    if ([self respondsToSelector:@selector(tbt_preprocessURLString:)]) {
        URLString = [self tbt_preprocessURLString:URLString];
    }
    return URLString;
}

- (id)validRequestParameter {
    id parameter = self.requestParameter;
    if ([self respondsToSelector:@selector(tbt_preprocessParameter:)]) {
        parameter = [self tbt_preprocessParameter:parameter];
    }
    return parameter;
}

#pragma mark - Getter
- (TBTNetworkCache *)cacheHandler {
    if (!_cacheHandler) {
        _cacheHandler = [TBTNetworkCache new];
    }
    return _cacheHandler;
}

@end
