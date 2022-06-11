//
//  TBTNetworkManager.h
//  TBT
//
//  Created by 刘冉 on 2022/6/10.
//

#import <Foundation/Foundation.h>
#import "TBTNetworkHeader.h"

NS_ASSUME_NONNULL_BEGIN

@class TBTNetworkResponse,TBTBaseRequest;

typedef void(^TBTRequestCompletionBlock)(TBTNetworkResponse *response);

@interface TBTNetworkManager : NSObject

+ (instancetype)sharedManager;

- (nullable NSNumber *)startNetworkingWithRequest:(TBTBaseRequest *)request
                                   uploadProgress:(nullable TBTRequestProgressBlock)uploadProgress
                                 downloadProgress:(nullable TBTRequestProgressBlock)downloadProgress
                                       completion:(nullable TBTRequestCompletionBlock)completion;

- (void)cancelNetworkingWithSet:(NSSet<NSNumber *> *)set;

- (instancetype)init OBJC_UNAVAILABLE("use '+sharedManager' instead");
+ (instancetype)new OBJC_UNAVAILABLE("use '+sharedManager' instead");

@end

NS_ASSUME_NONNULL_END
