//
//  YPWebImageDownloader.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YPWebImageCompat.h"
#import "YPWebImageOperation.h"

typedef NS_ENUM(NSInteger, YPWebImageDownloaderExecutionOrder) {
    /** 默认值,所有下载操作在队列中的执行顺序为先进先出 */
    YPWebImageDownloaderFIFOExecutionOrder,
    /** 所有下载操作将执行在栈中顺序为后进先出 */
    YPWebImageDownloaderLIFOExecutionOrder
};

/** 下载完成时的回调 */
typedef void(^YPWebImageDownloaderCompletedBlock)(UIImage *downloadedImage, NSData *data, NSError *error, BOOL finished);
/** 这个block将在每次图片下载时调用,返回一个将要包含相应请求头的字典 */
typedef NSDictionary *(^YPWebImageDownloaderHeadersFilterBlock)(NSURL *url, NSDictionary *headers);

/**
 *  专门用来优化图片异步下载的下载类
 */
@interface YPWebImageDownloader : NSObject


/** 单例 */
+ (YPWebImageDownloader *)sharedDownloader;

/**
 *  设置下载队列停止的方法
 */
- (void)setSuspended:(BOOL)suspended;

/**
 *  创建一个SDWebImageDownloader是一个异步下载的实例根据给定的url
 *
 *  当图片下载完成或者失败的时候代理会被告知
 */
- (id <YPWebImageOperation>)downloadImageWithURL:(NSURL *)url completed:(YPWebImageDownloaderCompletedBlock)completedBlock;

@end
