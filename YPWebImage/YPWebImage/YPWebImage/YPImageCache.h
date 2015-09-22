//
//  YPImageCache.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YPWebImageCompat.h"


typedef NS_ENUM(NSInteger, YPImageCacheType) {
    /** 图片不能够从缓存中加载,也就是说是从网络上下载 */
    YPImageCacheTypeNone,
    /** 该图像是从沙盒中存储的 */
    YPImageCacheTypeDisk,
    /** 该图像是从内存中缓存的 */
    YPImageCacheTypeMemory
};

typedef void(^YPWebImageQueryCompletedBlock)(UIImage *image, YPImageCacheType cacheType);

@interface YPImageCache : NSObject

/**
 *  是否解压缩图片
 *  虽然将下载的图片进行解压缓存能够提高效果,但是这样做会消耗大量内存
 *  默认为YES.但是如果你遇到了由于内存消耗引起的崩溃可以将这个BOOL值设置为NO
 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

/** 是否关闭iCloud备份,默认是yes(关闭备份) */
@property (assign, nonatomic) BOOL shouldDisableiCloud;

/** 使用内存缓存 默认为YES */
@property (assign, nonatomic) BOOL shouldCacheImagesInMemory;

/** 沙盒缓存的最大缓存时长,以秒为单位 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/** 最大缓存容量 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

/** 单例 */
+ (YPImageCache *)sharedImageCache;

/**
 *  以指定的名字初始化一个新的缓存空间
 *
 *  @param ns 这个命名控件被使用到这个缓存文件夹根目录名
 */
- (id)initWithNamespace:(NSString *)ns;

/**
 *  初始化一个新的缓存控件以一个指定的命名空间和一个目录名
 *
 *  @param ns        命名控件
 *  @param directory 目录名
 */
- (id)initWithNamespace:(NSString *)ns diskCacheDirectory:(NSString *)directory;

/**
 *  异步查询缓存
 *
 *  @param key       独特存放图像的key
 *  @param doneBlock 查询完成的回调
 */
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(YPWebImageQueryCompletedBlock)doneBlock;

/**
 *  根据key值异步的在内存中查询
 *
 *  @param key 代表想要存储的图片的唯一的key值
 */
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key;

/**
 *  根据key获得一个默认的缓存路径
 */
- (NSString *)defaultCachePathForKey:(NSString *)key;

/**
 *  根据key与缓存根路径获取缓存的全路径
 */
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path;

/**
 *  清除内存中所有的图片缓存
 */
- (void)clearMemory;

/**
 *  从沙盒中移除所有的过期缓存图像
 */
- (void)cleanDisk;

/**
 *  清除沙盒中所有的过期缓存图片。非阻塞方法 - 立即返回
 *
 *  @param completionBlock 在缓存过期完成后执行的block(可选)
 */
- (void)cleanDiskWithCompletionBlock:(YPWebImageNoParamsBlock)completionBlock;

/**
 *  存储一张图片到内存或可选的沙盒根据一个关键字
 */
- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk;

@end
