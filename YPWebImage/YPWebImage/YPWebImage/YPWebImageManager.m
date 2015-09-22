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

/** 负责管理缓存 */
@property (strong, nonatomic, readwrite) YPImageCache *imageCache;
/** 负责管理下载 */
@property (strong, nonatomic, readwrite) YPWebImageDownloader *imageDownloader;
/** 正在运行的操作数组,包含所有当前正在下载的操作对象 */
@property (strong, nonatomic) NSMutableArray *runningOperations;

@end


@implementation YPWebImageManager

#pragma mark - 单例 -
+ (id)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}
#pragma mark - 初始化 -
- (id)init {
    if ((self = [super init])) {
        // 创建缓存对象
        _imageCache = [YPImageCache sharedImageCache];
        // 创建下载对象
        _imageDownloader = [YPWebImageDownloader sharedDownloader];
        // 初始化正在运行的操作数组
        _runningOperations = [NSMutableArray array];
    }
    return self;
}

#pragma mark - 功能性方法 -
/**
 *  根据url获取一个对应的key
 */
- (NSString *)cacheKeyForURL:(NSURL *)url
{
    // 直接返回这个url的绝对路径
    return [url absoluteString];
}

- (id<YPWebImageOperation>)downloadImageWithURL:(NSURL *)url completed:(YPWebImageCompletionWithFinishedBlock)completedBlock
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
    
    
    if (!url) { // 如果url不存在或者这个url是之前失败过的
        
        dispatch_main_sync_safe(^{ // 强行回到主线程
            // 搞一个错误对象(url不存在)
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil];
            // 回调block(图片传nil,错误信息,没有缓存策略,完成标志传YES,url传过去)
            completedBlock(nil, error, YPImageCacheTypeNone, YES, url);
        });
        
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
        
        if (operation.isCancelled) { // 如果操作被取消了
            @synchronized (self.runningOperations) { // 给正在运行的操作数组加锁
                // 将操作移除正在运行的操作数组
                [self.runningOperations removeObject:operation];
            }
            // 返回
            return;
        }
        
        if (!image) { // 如果内存沙盒中都没有这张图片(没有缓存过),则开启下载操作
            // 下载对象执行下载操作返回一个子操作
            id <YPWebImageOperation> subOperation = [self.imageDownloader downloadImageWithURL:url completed:^(UIImage *downloadedImage, NSData *data, NSError *error, BOOL finished) {
                if (weakOperation.isCancelled)
                { // 如果操作被取消了什么都不做
                }
                else
                { // 如果操作没有被取消且没有错误
                    if (downloadedImage) { // 如果已经下载的图片有值 并且已经完成
                        // 直接缓存下载的图片 翻转为NO
                        [self.imageCache storeImage:downloadedImage recalculateFromImage:NO imageData:data forKey:key toDisk:YES];
                    }
                    
                    dispatch_main_sync_safe(^{ // 强行回到主线程
                        if (!weakOperation.isCancelled) { // 如果操作没有被取消
                            // 回调完成的block 传入转换后的图片,错误为nil,缓存策略为默认网络加载,完成YES,url
                            completedBlock(downloadedImage, nil, YPImageCacheTypeNone, finished, url);
                        }
                    });
                }
                
                if (finished) { // 如果完成
                    @synchronized (self.runningOperations) { // 给正在运行的操作数组加锁
                        // 将操作移除当前运行的操作数组
                        [self.runningOperations removeObject:operation];
                    }
                }
            }];
            
            operation.cancelBlock = ^{ // 回调取消block
                // 取消操作
                [subOperation cancel];
                
                @synchronized (self.runningOperations) { // 给正在运行的操作数组加锁
                    // 将操作移除当前运行的操作数组
                    [self.runningOperations removeObject:weakOperation];
                }
            };
        } else if (image) { // 如果缓存中图片有值
            dispatch_main_sync_safe(^{ // 强行回到主线程
                if (!weakOperation.isCancelled) { // 如果操作没有被取消
                    // 回调完成的block(图片,错误为nil,当前的缓存策略,完成yes,图片url)
                    completedBlock(image, nil, cacheType, YES, url);
                }
            });
            @synchronized (self.runningOperations) { // 给正在运行的操作数组加锁
                // 将操作移除正在操作的数组
                [self.runningOperations removeObject:operation];
            }
        } else { // 如果以上情况都不是
            // 图片没有在缓存中并且下载不允许通过delegate
            dispatch_main_sync_safe(^{ // 强行回到主线程
                if (!weakOperation.isCancelled) { // 如果操作没有被取消
                    // 回调完成的block(图片,错误为nil,从网络上下载的缓存策略,完成yes,图片url)
                    completedBlock(nil, nil, YPImageCacheTypeNone, YES, url);
                }
            });
            @synchronized (self.runningOperations) { // 给正在运行的操作数组加锁
                // 将操作移除正在操作的数组
                [self.runningOperations removeObject:operation];
            }
        }
    }];
    
    return operation;
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

























