//
//  YPWebImageDownloader.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPWebImageDownloader.h"
#import "YPWebImageDownloaderOperation.h"
#import <ImageIO/ImageIO.h>

/** 完成回调的key */
static NSString *const kCompletedCallbackKey = @"completed";

@interface YPWebImageDownloader()

/**
 *  解压缩正在下载的图片并缓存可以提高效果，但会消耗大量的内存。
 *  默认是YES. 如果你因为内存的消耗导致的崩溃时可以将这个值设置为NO
 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

/** 设置队列的最大并发操作数量,默认为6个 */
@property (assign, nonatomic) NSInteger maxConcurrentDownloads;

/** 显示当前下载的总数 */
@property (readonly, nonatomic) NSUInteger currentDownloadCount;

/** 下载操作的过期时间(以秒为单位) 默认为15秒 */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;

/** 改变下载操作的执行顺序,默认是SDWebImageDownloaderFIFOExecutionOrder顺序(先进先出) */
@property (assign, nonatomic) YPWebImageDownloaderExecutionOrder executionOrder;

/**
 *  设置一个过滤器来选择下载图片的HTTP请求头
 *
 *  这个block将在每次图片下载时调用,返回一个将要包含相应请求头的字典
 */
@property (nonatomic, copy) YPWebImageDownloaderHeadersFilterBlock headersFilter;

/** 下载队列 */
@property (strong, nonatomic) NSOperationQueue *downloadQueue;
/** 上次添加的队列 */
@property (weak, nonatomic) NSOperation *lastAddedOperation;
/** 操作的类 */
@property (assign, nonatomic) Class operationClass;
/** URL回调的可变字典 */
@property (strong, nonatomic) NSMutableDictionary *URLCallbacks;
/** 请求头字典 */
@property (strong, nonatomic) NSMutableDictionary *HTTPHeaders;
/**
 *  这个队列主要用于单一的串行化网络响应处理
 *他的优点在于,前面的任务执行结束后它才执行，而且它后面的任务要等它执行完成之后才会执行
 */
@property (strong, nonatomic) dispatch_queue_t barrierQueue;

@end

@implementation YPWebImageDownloader

+ (YPWebImageDownloader *)sharedDownloader
{
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

/** 对象初始化操作 */
- (id)init {
    if ((self = [super init])) {
        // 获取YPWebImageDownloaderOperation这个类
        _operationClass = [YPWebImageDownloaderOperation class];
        // 默认解压缩图片为YES
        _shouldDecompressImages = YES;
        // 初始化执行顺序为先进先出
        _executionOrder = YPWebImageDownloaderFIFOExecutionOrder;
        // 初始化下载队列
        _downloadQueue = [NSOperationQueue new];
        // 设置队列的最大并发操作数量为6个
        _downloadQueue.maxConcurrentOperationCount = 6;
        // 初始化url的回调字典
        _URLCallbacks = [NSMutableDictionary dictionary];
        // 初始化HTTP头
        _HTTPHeaders = [@{@"Accept": @"image/*;q=0.8"} mutableCopy];
        // 初始化串行队列
        _barrierQueue = dispatch_queue_create("com.hackemist.SDWebImageDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        // 初始化过期时间15秒
        _downloadTimeout = 15.0;
    }
    return self;
}

/**
 *  当下载对象被销毁,取消内部所有的下载操作,释放串行队列
 */
- (void)dealloc
{
    [self.downloadQueue cancelAllOperations];
    
    YPDispatchQueueRelease(_barrierQueue);
}

- (id <YPWebImageOperation>)downloadImageWithURL:(NSURL *)url completed:(YPWebImageDownloaderCompletedBlock)completedBlock
{
    // 搞一个下载操作
    __block YPWebImageDownloaderOperation *operation;
    // 取消强引用
    __weak __typeof(self)wself = self;
    
    // 处理避免对一张图片发送重复请求的方法
    [self addCallback:completedBlock forURL:url createCallback:^{
        
        // 获取超时时间,默认15秒
        NSTimeInterval timeoutInterval = wself.downloadTimeout;
        
        if (timeoutInterval == 0.0) { // 如果获取的超时时间为0.5
            // 将超时时间设置为15
            timeoutInterval = 15.0;
        }
        
        /**
         *  首先以一种缓存策略创建一个可变的请求,NSURLRequestReloadIgnoringLocalCacheData策略
         */
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:0 timeoutInterval:timeoutInterval];
        
        // HTTPShouldUsePipelining 也出现在NSMutableURLRequest，它可以被用于开启HTTP管道，这可以显着降低请求的加载时间，但是由于没有被服务器广泛支持，默认是禁用的。
        request.HTTPShouldUsePipelining = YES;
        
        if (wself.headersFilter) { // 如果block有值,回调block
            // 返回一个包含所有接受者HTTP头区域的字典。[wself.HTTPHeaders copy]
            request.allHTTPHeaderFields = wself.headersFilter(url, [wself.HTTPHeaders copy]);
        }
        else { // 如果block没有值 直接wself.HTTPHeaders 赋值
            request.allHTTPHeaderFields = wself.HTTPHeaders;
        }
        
        operation = [[wself.operationClass alloc] initWithRequest:request completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
            // 获取一下当前的Downloader
            YPWebImageDownloader *sself = wself;
            // 如果为空马上返回
            if (!sself) return;
            // 搞一个回调URL的数组
            __block NSArray *callbacksForURL;
            dispatch_barrier_sync(sself.barrierQueue, ^{ // 前面的任务执行结束后它才执行，而且它后面的任务要等它执行完成之后才会执行。
                // 在当前Downloader的回调字典中以传入的url检索保存到回调URL数组中
                callbacksForURL = [sself.URLCallbacks[url] copy];
                if (finished) { // 如果完成了
                    // 将回调字典中的url键对应的对象删除
                    [sself.URLCallbacks removeObjectForKey:url];
                }
            });
            for (NSDictionary *callbacks in callbacksForURL) { // 遍历回调数组
                /**
                 *  static NSString *const kCompletedCallbackKey = @"completed";
                 *  根据kCompletedCallbackKey这个键值从回调字典中取出YPWebImageDownloaderCompletedBlock
                 */
                YPWebImageDownloaderCompletedBlock callback = callbacks[kCompletedCallbackKey];
                // 如果回调存在 进行回调
                if (callback) callback(image, data, error, finished);
            }
        } cancelled:^{ // 回调取消的block
            // 获取一下当前的Downloader
            YPWebImageDownloader *sself = wself;
            // 如果为空马上返回
            if (!sself) return;
            dispatch_barrier_async(sself.barrierQueue, ^{ // 前面的任务执行结束后它才执行，而且它后面的任务要等它执行完成之后才会执行。
                // 将回调字典中的url键对应的对象删除
                [sself.URLCallbacks removeObjectForKey:url];
            });
        }];
        
        // 给操作的shouldDecompressImages赋值
        operation.shouldDecompressImages = wself.shouldDecompressImages;
        
        operation.queuePriority = NSOperationQueuePriorityHigh; // 可选
        
        // 将这个操作加入到操作队列中
        [wself.downloadQueue addOperation:operation];

    }];
    
    // 返回操作
    return operation;
}

/**
 *  处理避免对一张图片发送重复请求的方法
 */
- (void)addCallback:(YPWebImageDownloaderCompletedBlock)completedBlock forURL:(NSURL *)url createCallback:(YPWebImageNoParamsBlock)createCallback {

    // 这个URL将被用作回调的字典key因此它不能为空,如果它为空就会立即调用完成的block传入空图片或空数据
    if (url == nil) { // 如果url为空
        if (completedBlock != nil) { // 如果completedBlock不为空
            // 进行空值回调
            completedBlock(nil, nil, nil, NO);
        }
        // 返回
        return;
    }
    
    /**
     *  前面的任务执行结束后它才执行，而且它后面的任务要等它执行完成之后才会执行。
     *  这个block内部主要用来处理避免对一张图片发送重复请求
     */
    dispatch_barrier_sync(self.barrierQueue, ^{
        BOOL first = NO;
        if (!self.URLCallbacks[url]) { // 如果url回调字典key url对应的数组不存在
            // 那么创建url回调数组
            self.URLCallbacks[url] = [NSMutableArray new];
            first = YES;
        }
        
        // Handle single download of simultaneous download request for the same URL
        // 用来处理对相同的URL发送重复请求的问题
        
        // 根据url这个key取出回调数组
        NSMutableArray *callbacksForURL = self.URLCallbacks[url];
        
        // 创建回调字典
        NSMutableDictionary *callbacks = [NSMutableDictionary new];
        
        // 存储完成的block
        if (completedBlock) callbacks[kCompletedCallbackKey] = [completedBlock copy];
        
        // 将回调字典加入回调数组中
        [callbacksForURL addObject:callbacks];
        
        // 重新以url key给URL回调的可变字典赋值
        self.URLCallbacks[url] = callbacksForURL;
        
        if (first) { // flag如果为YES 就回调
            createCallback();
        }
    });
}

/**
 *  停止下载队列
 */
- (void)setSuspended:(BOOL)suspended {
    [self.downloadQueue setSuspended:suspended];
}

@end












