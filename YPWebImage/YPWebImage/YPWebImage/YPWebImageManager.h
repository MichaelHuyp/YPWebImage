//
//  YPWebImageManager.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPWebImageOperation.h"
#import "YPWebImageCompat.h"
#import "YPWebImageDownloader.h"
#import "YPImageCache.h"

typedef void(^YPWebImageCompletionWithFinishedBlock)(UIImage *image, NSError *error, YPImageCacheType cacheType, BOOL finished, NSURL *imageURL);


@class YPWebImageManager;


@interface YPWebImageManager : NSObject


@property (strong, nonatomic, readonly) YPWebImageDownloader *imageDownloader;

/** 单例 */
+ (YPWebImageManager *)sharedManager;

/**
 *  根据url下载图片
 */
- (id <YPWebImageOperation>)downloadImageWithURL:(NSURL *)url completed:(YPWebImageCompletionWithFinishedBlock)completedBlock;

/**
 *  取消所有正在运行操作
 */
- (void)cancelAll;

/**
 *  检查一个或多个操作是否正在运行
 */
- (BOOL)isRunning;

/**
 *  返回一个缓存的Key根据url
 */
- (NSString *)cacheKeyForURL:(NSURL *)url;

@end
