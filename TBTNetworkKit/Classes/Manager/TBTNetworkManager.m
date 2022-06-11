//
//  TBTNetworkManager.m
//  TBT
//
//  Created by 刘冉 on 2022/6/10.
//

#import "TBTNetworkManager.h"
#import <pthread/pthread.h>
#import "TBTNetworkResponse.h"
#import "TBTBaseRequest.h"
#import "TBTBaseRequest+TBTInternal.h"

#define TBTNM_TASKRECORD_LOCK(...) \
pthread_mutex_lock(&self->_lock); \
__VA_ARGS__ \
pthread_mutex_unlock(&self->_lock);

@interface TBTNetworkManager ()
{
    pthread_mutex_t _lock;
}

@property (nonatomic,strong) NSMutableDictionary <NSNumber *,NSURLSessionTask *>*taskRecord;

@end

static TBTNetworkManager *manager = nil;

@implementation TBTNetworkManager

- (void)dealloc {
    NSLog(@"%s",__func__);
    pthread_mutex_destroy(&_lock);
}

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[super allocWithZone:NULL] initSpecially];
    });
    return manager;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [TBTNetworkManager sharedManager];
}

- (id)copyWithZone:(struct _NSZone *)zone {
    return [TBTNetworkManager sharedManager];
}

- (instancetype)initSpecially {
    if (self = [super init]) {
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

#pragma mark - private
- (void)cancelTaskWithIdentifier:(NSNumber *)identifier {
    TBTNM_TASKRECORD_LOCK(NSURLSessionTask *task = self.taskRecord[identifier];);
    if (task) {
        [task cancel];
        TBTNM_TASKRECORD_LOCK([self.taskRecord removeObjectForKey:identifier];);
    }
}

- (void)cancelAllTask {
    TBTNM_TASKRECORD_LOCK(
                          for(NSURLSessionTask *task in self.taskRecord) {
                              [task cancel];
                          }
                          [self.taskRecord removeAllObjects];
    );
}

- (NSNumber *)startDownloadTaskWithManager:(AFHTTPSessionManager *)manager URLRequest:(NSURLRequest *)URLRequest downloadPath:(NSString *)downloadPath  downloadProgress:(nullable TBTRequestProgressBlock)downloadProgress completion:(TBTRequestCompletionBlock)completion {
    // 保证下载路径是文件不是目录
    NSString *vaildDownloadPath = downloadPath.copy;
    BOOL isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:vaildDownloadPath isDirectory:&isDirectory]) {
        isDirectory = NO;
    }
    if (isDirectory) {
        vaildDownloadPath = [NSString pathWithComponents:@[vaildDownloadPath,URLRequest.URL.lastPathComponent]];
    }
    
    // 若文件存在则移除
    if ([[NSFileManager defaultManager] fileExistsAtPath:vaildDownloadPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:vaildDownloadPath error:nil];
    }
    
    __block NSURLSessionDownloadTask *task = [manager downloadTaskWithRequest:URLRequest progress:downloadProgress destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL fileURLWithPath:vaildDownloadPath isDirectory:NO];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        TBTNM_TASKRECORD_LOCK([self.taskRecord removeObjectForKey:@(task.taskIdentifier)];);
        if (completion) {
            completion([TBTNetworkResponse responseWithSessionTask:task responseObject:filePath error:error]);
        }
    }];
    
    NSNumber *taskIdentifier = @(task.taskIdentifier);
    TBTNM_TASKRECORD_LOCK(self.taskRecord[taskIdentifier] = task;);
    [task resume];
    return taskIdentifier;
}

- (NSNumber *)startDataTaskWithManager:(AFHTTPSessionManager *)manager URLRequest:(NSURLRequest *)URLRequest uploadProgress:(nullable TBTRequestProgressBlock)uploadProgressBlock downloadProgress:(nullable TBTRequestProgressBlock)downloadProgressBlock completion:(TBTRequestCompletionBlock)completion {
    __block NSURLSessionDataTask *task = [manager dataTaskWithRequest:URLRequest uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
        if (uploadProgressBlock) {
            uploadProgressBlock(uploadProgress);
        }
    } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
        if (downloadProgressBlock) {
            downloadProgressBlock(downloadProgress);
        }
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        TBTNM_TASKRECORD_LOCK([self.taskRecord removeObjectForKey:@(task.taskIdentifier)];);
        if (completion) {
            completion([TBTNetworkResponse responseWithSessionTask:task responseObject:responseObject error:error]);
        }
    }];
    
    NSNumber *taskIdentifier = @(task.taskIdentifier);
    TBTNM_TASKRECORD_LOCK(self.taskRecord[taskIdentifier] = task;);
    [task resume];
    return taskIdentifier;
}

#pragma mark - public methods
- (void)cancelNetworkingWithSet:(NSSet<NSNumber *> *)set {
    TBTNM_TASKRECORD_LOCK(
                          for(NSNumber *taskIdentifier in set) {
                              NSURLSessionTask *task = self.taskRecord[taskIdentifier];
                              if (task) {
                                  [task cancel];
                                  [self.taskRecord removeObjectForKey:taskIdentifier];
                              }
                          }
    );
}

- (NSNumber *)startNetworkingWithRequest:(TBTBaseRequest *)request uploadProgress:(TBTRequestProgressBlock)uploadProgress downloadProgress:(TBTRequestProgressBlock)downloadProgress completion:(TBTRequestCompletionBlock)completion {
    // 构建网络请求数据
    NSString *method = [request requestMethodString];
    AFHTTPRequestSerializer *serializer = [self requestSerializerForRequest:request];
    NSString *URLString = [request validRequestURLString];
    id parameter = [request validRequestParameter];
    
    // 构建Request
    NSError *error = nil;
    NSMutableURLRequest *URLRequest = nil;
    if (request.requestConstructingBody) {
        URLRequest = [serializer multipartFormRequestWithMethod:@"POST" URLString:URLString parameters:parameter constructingBodyWithBlock:request.requestConstructingBody error:&error];
    } else {
        URLRequest = [serializer requestWithMethod:method URLString:URLString parameters:parameter error:&error];
    }
    
    if (error) {
        if (completion) {
            completion([TBTNetworkResponse responseWithSessionTask:nil responseObject:nil error:error]);
            return nil;
        }
    }
    
    // 发起网络请求
    AFHTTPSessionManager *manager = [self sessionManagerForRequest:request];
    if (request.downloadPath.length > 0) {
        return [self startDownloadTaskWithManager:manager URLRequest:URLRequest downloadPath:request.downloadPath downloadProgress:downloadProgress completion:completion];
    } else {
        return [self startDataTaskWithManager:manager URLRequest:URLRequest uploadProgress:uploadProgress downloadProgress:downloadProgress completion:completion];
    }
}

#pragma mark - read info from request
- (AFHTTPRequestSerializer *)requestSerializerForRequest:(TBTBaseRequest *)request {
    AFHTTPRequestSerializer *serializer = request.requestSerializer ?: [AFHTTPRequestSerializer serializer];
    if (request.requestTimeoutInterval > 0) {
        serializer.timeoutInterval = request.requestTimeoutInterval;
    }
    return serializer;
}

- (AFHTTPSessionManager *)sessionManagerForRequest:(TBTBaseRequest *)request {
    AFHTTPSessionManager *mannager = request.sessionManager;
    if (!mannager) {
        static AFHTTPSessionManager *defaultManager = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            defaultManager = [AFHTTPSessionManager new];
        });
        mannager = defaultManager;
    }
    mannager.completionQueue = dispatch_queue_create("com.tbtNetwork.completionQueue", DISPATCH_QUEUE_CONCURRENT);
    AFHTTPResponseSerializer *customSerializer = request.responseSerializer;
    if (customSerializer) {
        mannager.responseSerializer = customSerializer;
    }
    return mannager;
}

#pragma mark - Getter
- (NSMutableDictionary<NSNumber *,NSURLSessionTask *> *)taskRecord {
    if (!_taskRecord) {
        _taskRecord = [NSMutableDictionary dictionary];
    }
    return _taskRecord;
}

@end
