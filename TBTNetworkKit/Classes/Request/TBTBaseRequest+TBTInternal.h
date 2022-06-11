//
//  TBTBaseRequest+TBTInternal.h
//  TBT
//
//  Created by 刘冉 on 2022/6/10.
//

#import "TBTBaseRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface TBTBaseRequest (TBTInternal)

/// 请求方法字符串
- (NSString *)requestMethodString;
/// 请求 URL 字符串
- (NSString *)validRequestURLString;
/// 请求参数字符串
- (id)validRequestParameter;

@end

NS_ASSUME_NONNULL_END
