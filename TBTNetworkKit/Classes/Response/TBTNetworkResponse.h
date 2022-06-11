//
//  TBTNetworkResponse.h
//  TBT
//
//  Created by 刘冉 on 2022/6/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 网络请求响应对象
 若想拓展属性，可以使用 runtime 关联属性，重写预处理方法进行计算并赋值就好了
 */
@interface TBTNetworkResponse : NSObject

/// 请求成功数据
@property (nonatomic, strong, nullable) id responseObject;
/// 请求失败 NSError
@property (nonatomic, strong, readonly, nullable) NSError *error;
/// 请求任务
@property (nonatomic, strong, readonly, nullable) NSURLSessionTask *sessionTask;
/// sessionTask.response
@property (nonatomic, strong, readonly, nullable) NSHTTPURLResponse *URLResponse;

/// 便利构造
+ (instancetype)responseWithSessionTask:(nullable NSURLSessionTask *)sessionTask
                         responseObject:(nullable id)responseObject
                                  error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
