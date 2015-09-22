//
//  YPWebImageDownloaderOperation.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPWebImageDownloaderOperation.h"
#import "UIImage+YPForceDecode.h"
#import "UIImage+YPMultiFormat.h"
#import <ImageIO/ImageIO.h>
#import "YPWebImageManager.h"


@interface YPWebImageDownloaderOperation() <NSURLConnectionDataDelegate>

@property (strong, nonatomic, readonly) NSURLRequest *request;

/** 完成的回调block */
@property (copy, nonatomic) YPWebImageDownloaderCompletedBlock completedBlock;

/** 取消的回调block */
@property (copy, nonatomic) YPWebImageNoParamsBlock cancelBlock;

/** 操作是否正在执行 */
@property (assign, nonatomic, getter = isExecuting) BOOL executing;

/** 操作是否已经完成 */
@property (assign, nonatomic, getter = isFinished) BOOL finished;

/** 图片下载的数据 */
@property (strong, nonatomic) NSMutableData *imageData;

/** NSURLConnection */
@property (strong, nonatomic) NSURLConnection *connection;

/** NSThread */
@property (strong, atomic) NSThread *thread;

#if TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
/** 后台任务标识符 */
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;
#endif

@end

@implementation YPWebImageDownloaderOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (id)initWithRequest:(NSURLRequest *)request completed:(YPWebImageDownloaderCompletedBlock)completedBlock cancelled:(YPWebImageNoParamsBlock)cancelBlock
{
    if ((self = [super init])) {
        _request = request;
        // 默认解压缩图片
        _shouldDecompressImages = YES;
        // 初始化回调block
        _completedBlock = [completedBlock copy];
        // 初始化取消的回调block
        _cancelBlock = [cancelBlock copy];
        // 正在执行参数
        _executing = NO;
        // 完成参数
        _finished = NO;
    }
    return self;
}

/**
 *  调用start方法即可开始执行操作
 */
- (void)start
{
    @synchronized (self) { // 对当前对象加锁
        if (self.isCancelled) { // 如果对象已经取消了
            // 将finished设置为YES
            self.finished = YES;
            // 清空操作
            [self reset];
            // 返回
            return;
        }
#if TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
    // 获取UIApplication
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
    // 如果UIApplication存在并且准去App进入后台继续操作
    if (hasApplication) {
        __weak __typeof__ (self) wself = self;
        UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
        self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
            __strong __typeof (wself) sself = wself;
            
            if (sself) {
                [sself cancel];
                
                [app endBackgroundTask:sself.backgroundTaskId];
                sself.backgroundTaskId = UIBackgroundTaskInvalid;
            }
        }];
    }
#endif
        self.executing = YES;
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        self.thread = [NSThread currentThread];
    }
    
    [self.connection start];
    
    if (self.connection) { // 如果有连接
        
        // 在默认模式下运行当前runlooprun，直到调用CFRunLoopStop停止运行
        CFRunLoopRun();
        
        if (!self.isFinished) { // 如果没有完成
            [self.connection cancel]; // 取消连接
            // 发送错误信息
            [self connection:self.connection didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:@{NSURLErrorFailingURLErrorKey : self.request.URL}]];
        }
    }
    else { // 如果连接为空
        if (self.completedBlock) { // 回调错误信息链接不能被初始化
            self.completedBlock(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Connection can't be initialized"}], YES);
        }
    }
    
#if TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
#endif
}

- (void)cancel {
    @synchronized (self) {
        if (self.thread) {
            [self performSelector:@selector(cancelInternalAndStop) onThread:self.thread withObject:nil waitUntilDone:NO];
        }
        else {
            [self cancelInternal];
        }
    }
}

- (void)cancelInternalAndStop {
    if (self.isFinished) return;
    [self cancelInternal];
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)cancelInternal {
    if (self.isFinished) return;
    [super cancel];
    if (self.cancelBlock) self.cancelBlock();
    
    if (self.connection) {
        [self.connection cancel];
        // As we cancelled the connection, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }
    
    [self reset];
}

/**
 *  清空操作
 */
- (void)reset {
    // 将所有参数设置为nil
    self.cancelBlock = nil;
    self.completedBlock = nil;
    self.connection = nil;
    self.imageData = nil;
    self.thread = nil;
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

#pragma mark - KVO -
- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent {
    return YES;
}

- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image {
    return YPScaledImageForKey(key, image);
}


#pragma mark NSURLConnection (delegate)

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    NSInteger expected = response.expectedContentLength > 0 ? (NSInteger)response.expectedContentLength : 0;
    
    self.imageData = [[NSMutableData alloc] initWithCapacity:expected];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    // 拼接图片数据
    [self.imageData appendData:data];

}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    @synchronized(self) {
        CFRunLoopStop(CFRunLoopGetCurrent());
        self.thread = nil;
        self.connection = nil;

    }
    
    if (self.completedBlock) {
        self.completedBlock(nil, nil, error, YES);
    }
    self.completionBlock = nil;
    [self done];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection {
    YPWebImageDownloaderCompletedBlock completionBlock = self.completedBlock;
    @synchronized(self) {
        CFRunLoopStop(CFRunLoopGetCurrent());
        self.thread = nil;
        self.connection = nil;
    }
    if (completionBlock) {
        
        if (self.imageData) {
            UIImage *image = [UIImage imageWithMultiFormatData:self.imageData];
            NSString *key = [[YPWebImageManager sharedManager] cacheKeyForURL:self.request.URL];
            image = [self scaledImageForKey:key image:image];
            
            // Do not force decoding animated GIFs
            if (!image.images) {
                if (self.shouldDecompressImages) {
                    image = [UIImage decodedImageWithImage:image];
                }
            }
            if (CGSizeEqualToSize(image.size, CGSizeZero)) {
            }
            else {
                completionBlock(image, self.imageData, nil, YES);
            }
        }
    }
    self.completionBlock = nil;
    [self done];
}


- (BOOL)shouldContinueWhenAppEntersBackground {
    return YES;
}





@end














