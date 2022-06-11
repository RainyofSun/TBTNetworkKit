//
//  TBTNetworkCache.m
//  TBT
//
//  Created by 刘冉 on 2022/6/10.
//

#import "TBTNetworkCache.h"

@interface TBTNetworkCachePackage : NSObject<NSCoding>

@property (nonatomic,strong) id<NSCoding> object;
@property (nonatomic,strong) NSDate *updateDate;

@end

@implementation TBTNetworkCachePackage

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        self.object = [coder decodeObjectForKey:NSStringFromSelector(@selector(object))];
        self.updateDate = [coder decodeObjectForKey:NSStringFromSelector(@selector(updateDate))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.object forKey:NSStringFromSelector(@selector(object))];
    [coder encodeObject:self.updateDate forKey:NSStringFromSelector(@selector(updateDate))];
}

- (void)dealloc {
    NSLog(@"%s",__func__);
}

@end

static NSString *const TBTNetworkCacheName = @"TBTNetworkCacheName";
static YYDiskCache *_diskCache = nil;
static YYMemoryCache *_memoryCache = nil;

@implementation TBTNetworkCache

- (instancetype)init {
    if (self = [super init]) {
        self.writeMode = TBTNetworkCacheWriteMode_None;
        self.readMode = TBTNetworkCacheReadMode_None;
        self.ageSeconds = 0;
        self.extraCacheKey = [@"v" stringByAppendingString:[[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"]];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%s",__func__);
}

#pragma mark - public methods
+ (NSInteger)getDiskCacheSize {
    return [TBTNetworkCache.diskCache totalCost] / 1024.0/1024.0;
}

+ (void)removeDiskCache {
    [TBTNetworkCache.diskCache removeAllObjects];
}

+ (void)removeMemeryCache {
    [TBTNetworkCache.memoryCache removeAllObjects];
}

#pragma mark - Category
- (void)setObject:(id<NSCoding>)object forKey:(id)key {
    if (self.writeMode == TBTNetworkCacheWriteMode_None) {
        return;
    }
    TBTNetworkCachePackage *package = [[TBTNetworkCachePackage alloc] init];
    package.object = object;
    package.updateDate = [NSDate date];
    
    if (self.writeMode & TBTNetworkCacheWriteMode_Memory) {
        [TBTNetworkCache.memoryCache setObject:object forKey:key];
    }
    
    if (self.writeMode & TBTNetworkCacheWriteMode_Disk) {
        // 子线程执行
        [TBTNetworkCache.diskCache setObject:object forKey:key withBlock:^{
            
        }];
    }
}

- (void)objectForKey:(NSString *)key withBlock:(void(^)(NSString *key, id<NSCoding> _Nullable object))block {
    if (!block) {
        return;
    }
    
    void(^callback)(id<NSCoding>) = ^(id<NSCoding> obj) {
        TBTNETWORK_MAIN_QUEUE_ASYNC(^{
            if (obj && [(NSObject *)obj isKindOfClass:[TBTNetworkCachePackage class]]) {
                TBTNetworkCachePackage *package = (TBTNetworkCachePackage *)obj;
                if (self.ageSeconds != 0 && -[package.updateDate timeIntervalSinceNow] > self.ageSeconds) {
                    block(key,nil);
                } else {
                    block(key,package.object);
                }
            } else {
                block(key,nil);
            }
        });
    };
    
    id<NSCoding> object = [TBTNetworkCache.memoryCache objectForKey:key];
    if (object) {
        callback(object);
    } else {
        [TBTNetworkCache.diskCache objectForKey:key withBlock:^(NSString * _Nonnull key, id<NSCoding>  _Nullable object) {
            if (object && ![TBTNetworkCache.memoryCache containsObjectForKey:key]) {
                [TBTNetworkCache.memoryCache setObject:object forKey:key];
            }
            callback(object);
        }];
    }
}

#pragma mark - getter & setter
+ (YYDiskCache *)diskCache {
    if (!_diskCache) {
        NSString *cacheCoder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        NSString *path = [cacheCoder stringByAppendingPathComponent:TBTNetworkCacheName];
        _diskCache = [[YYDiskCache alloc] initWithPath:path];
    }
    return _diskCache;
}

+ (void)setDiskCache:(YYDiskCache *)diskCache {
    _diskCache = diskCache;
}

+ (YYMemoryCache *)memoryCache {
    if (!_memoryCache) {
        _memoryCache = [[YYMemoryCache alloc] init];
        _memoryCache.name = TBTNetworkCacheName;
    }
    return _memoryCache;
}

+ (void)setMemoryCache:(YYMemoryCache *)memoryCache {
    _memoryCache = memoryCache;
}

@end
