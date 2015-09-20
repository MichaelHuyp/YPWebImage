//
//  YPWebImageManager.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPWebImageManager.h"
#import "YPWebImageCombinedOperation.h"


@interface YPWebImageManager()

@property (strong, nonatomic, readwrite) YPImageCache *imageCache;
@property (strong, nonatomic, readwrite) YPWebImageDownloader *imageDownloader;
/** 请求失败的url集合 */
@property (strong, nonatomic) NSMutableSet *failedURLs;
/** 正在运行的操作数组 */
@property (strong, nonatomic) NSMutableArray *runningOperations;

@end


@implementation YPWebImageManager

static id _instance;

+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (id)init {
    if ((self = [super init])) {
        _imageCache = [self createCache];
        _imageDownloader = [YPWebImageDownloader sharedDownloader];
        _failedURLs = [NSMutableSet set];
        _runningOperations = [NSMutableArray array];
    }
    return self;
}

- (YPImageCache *)createCache {
    return [YPImageCache sharedImageCache];
}

- (id<YPWebImageOperation>)downloadImageWithURL:(NSURL *)url
{
    // 当使用者不小心将url输错输为了url字符串,自动帮他转化一下
    if ([url isKindOfClass:[NSString class]]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    
    /**
     *  防止应用程序崩溃参数类型的错误，如发送NSURL的NSNull代替
     */
    if (![url isKindOfClass:NSURL.class]) { // 传入的url既不是NSString也不是NSURL对象就将其指针设置为nil
        url = nil;
    }
    
    __block YPWebImageCombinedOperation *operation = [[YPWebImageCombinedOperation alloc] init];
    __weak YPWebImageCombinedOperation *weakOperation = operation;
    
    // 将失败url flag 设置为NO 这个flag的作用就是为了判断传入的url是否是以前加载失败的url
    BOOL isFailedUrl = NO;
    
    @synchronized(self.failedURLs) { // 给失败url集合中加锁
        // 如果这个失败url集合中包含传入的url就将失败url flag设置为YES
        isFailedUrl = [self.failedURLs containsObject:url];
    }
    
    if (!url || isFailedUrl) { // 如果url不存在或者这个url是之前失败过的
        // 直接返回这个operation
        return operation;
    }
    
    
    @synchronized (self.runningOperations) { // 给正在运行的操作数组加锁
        // 如果url一切正常就把这个自定义操作对象保存到正在运行的操作数组中
        [self.runningOperations addObject:operation];
    }
    
    // 根据url获取一个对应的key
    NSString *key = [self cacheKeyForURL:url];

    // 根据url的key从缓存中查询,并且在查询结束后触发block回调
    operation.cacheOperation = [self.imageCache queryDiskCacheForKey:key done:^(UIImage *image, YPImageCacheType cacheType) {
        // code
    }];
    
    return operation;
}

/**
 *  根据url获取一个对应的key
 */
- (NSString *)cacheKeyForURL:(NSURL *)url
{
    // 直接返回这个url的绝对路径
    return [url absoluteString];
}

- (void)cancelAll {
    @synchronized (self.runningOperations) { // 给正在运行的操作数组加锁
        // copy一份正在运行的操作数组
        NSArray *copiedOperations = [self.runningOperations copy];
        // 将copy的这份操作数组内的所有对象都是用cancel方法
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        // 将copy的这份数组从runningOperations中移除
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

- (BOOL)isRunning {
    // 如果正在运行的操作数组内的操作个数大于0 就表示正在运行
    return self.runningOperations.count > 0;
}

@end

























