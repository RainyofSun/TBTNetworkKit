//
//  TBTNetworkHeader.h
//  TBT
//
//  Created by 刘冉 on 2022/6/10.
//

#ifndef TBTNetworkHeader_h
#define TBTNetworkHeader_h

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

#define TBTNETWORK_QUEUE_ASYNC(queue, block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(queue)) == 0) {\
block();\
} else {\
dispatch_async(queue, block);\
}

#define TBTNETWORK_MAIN_QUEUE_ASYNC(block) TBTNETWORK_QUEUE_ASYNC(dispatch_get_main_queue(), block)

// 请求类型
typedef NS_ENUM(NSInteger,TBTRequestMethod) {
    TBTRequestMethod_GET,
    TBTRequestMethod_POST,
    TBTRequestMethod_DELETE,
    TBTRequestMethod_PUT,
    TBTRequestMethod_HEAD,
    TBTRequestMethod_PATCH
};

// 缓存存储模式
typedef NS_OPTIONS(NSInteger,TBTNetworkCacheWriteMode) {
    // 无缓存
    TBTNetworkCacheWriteMode_None = 0,
    // 内存缓存
    TBTNetworkCacheWriteMode_Memory = 1 << 0,
    // 磁盘缓存
    TBTNetworkCacheWriteMode_Disk = 1 << 1,
    TBTNetworkCacheWriteMode_MemoryAndDisk = TBTNetworkCacheWriteMode_Memory | TBTNetworkCacheWriteMode_Disk
};

// 缓存读取模式
typedef NS_ENUM(NSInteger, TBTNetworkCacheReadMode) {
    // 不读取缓存
    TBTNetworkCacheReadMode_None,
    // 缓存命中后仍然发起网络请求
    TBTNetworkCacheReadMode_SendNetwork,
    // 缓存命中后不发起网络请求
    TBTNetworkCacheReadMode_CancelNetwork
};

// 网络请求释放策略
typedef NS_ENUM(NSInteger, TBTNetworkReleaseStrategy) {
    // 网络任务会持有 TBTBaseRequest 实例，网络任务完成 TBTBaseRequest 才会释放
    TBTNetworkReleaseStrategy_HoldRequest,
    // 网络请求将随着 TBTBaseRequest 释放而释放
    TBTNetworkReleaseStrategy_WhenRequestDealloc,
    // 网络请求的释放和 TBTBaseRequest 实例无关
    TBTNetworkReleaseStrategy_NotCareRequest
};

// 重复网络请求处理策略
typedef NS_ENUM(NSInteger, TBTNetworkRepeatStrategy) {
    // 允许重复的网络请求
    TBTNetworkRepeatStrategy_AllAllowed,
    // 取消最旧的网络请求
    TBTNetworkRepeatStrategy_CancelOldest,
    // 取消最新的网络请求
    TBTNetworkRepeatStrategy_CancelNewest
};

// 网络请求重定向类型
typedef NS_ENUM(NSInteger, TBTRequestRedirection) {
    // 重定向成功
    TBTRequestRedirection_Success,
    // 重定向失败
    TBTRequestRedirection_Failure,
    // 停止后续操作（主要是停止回调）
    TBTRequestRedirection_Stop
};

@class TBTBaseRequest,TBTNetworkResponse;

/// 进度闭包
typedef void(^TBTRequestProgressBlock)(NSProgress *progress);
/// 缓存命中闭包
typedef void(^TBTRequestCacheBlock)(TBTNetworkResponse *response);
/// 请求成功闭包
typedef void(^TBTRequestSuccessBlock)(TBTNetworkResponse *response);
/// 请求失败闭包
typedef void(^TBTRequestFailureBlock)(TBTNetworkResponse *response);

// 网络请求响应代理
@protocol TBTResponseDelegate <NSObject>

@optional
/// 上传进度
- (void)request:(__kindof TBTBaseRequest *)request uploadProgress:(NSProgress *)progress;
/// 下载进度
- (void)request:(__kindof TBTBaseRequest *)request downloadProgress:(NSProgress *)progress;
/// 缓存命中
- (void)request:(__kindof TBTBaseRequest *)request cacheWithResponse:(TBTNetworkResponse *)response;
/// 请求成功
- (void)request:(__kindof TBTBaseRequest *)request successWithResponse:(TBTNetworkResponse *)response;
/// 请求失败
- (void)request:(__kindof TBTBaseRequest *)request failureWithResponse:(TBTNetworkResponse *)response;

@end
#endif /* TBTNetworkHeader_h */
