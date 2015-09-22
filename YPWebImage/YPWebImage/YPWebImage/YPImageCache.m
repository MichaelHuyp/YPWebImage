//
//  YPImageCache.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPImageCache.h"
#import "YPAutoPurgeCache.h"
#import "UIImage+YPMultiFormat.h"
#import "UIImage+YPForceDecode.h"
#import <CommonCrypto/CommonDigest.h>

/** 默认的缓存时间为1周 */
static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week
// PNG signature bytes and data (below)
// PNG的署名数组 十进制为 137 80 78 71 13 10 26 10
static unsigned char kPNGSignatureBytes[8] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
static NSData *kPNGSignatureData = nil;

/**
 *  根据图片数据判断PNG前缀来判断是否为PNG图片
 */
BOOL ImageDataHasPNGPreffix(NSData *data);
BOOL ImageDataHasPNGPreffix(NSData *data) {
    // 声明一个png的署名长度
    NSUInteger pngSignatureLength = [kPNGSignatureData length];
    if ([data length] >= pngSignatureLength) { // 如果传入的数据长度大于png署名长度
        if ([[data subdataWithRange:NSMakeRange(0, pngSignatureLength)] isEqualToData:kPNGSignatureData]) { // 如果图片数据是PNG署名的数据返回YES
            return YES;
        }
    }
    // 否则返回NO
    return NO;
}

/**
 *  计算图片的缓存花费(容量)
 */
FOUNDATION_STATIC_INLINE NSUInteger YPCacheCostForImage(UIImage *image) {
    // 图片的高度 * 图片的宽度 * 图片的伸缩度 * 图片的伸缩度
    return image.size.height * image.size.width * image.scale * image.scale;
}

@interface YPImageCache()

/** 内存缓存方式NSCache */
@property (strong, nonatomic) NSCache *memCache;

/** 缓存队列 */
@property (strong, nonatomic) dispatch_queue_t ioQueue;

/** 沙盒缓存路径 */
@property (strong, nonatomic) NSString *diskCachePath;

/** 自定义路径的数组 */
@property (strong, nonatomic) NSMutableArray *customPaths;

@end

@implementation YPImageCache
{
    /** 文件管理者 */
    NSFileManager *_fileManager;
}

/** 单例 */
+ (YPImageCache *)sharedImageCache
{
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

#pragma mark - init -

- (id)init {
    return [self initWithNamespace:@"default"];
}

- (id)initWithNamespace:(NSString *)ns {
    /** 获取沙盒初始化路径 */
    NSString *path = [self makeDiskCachePath:ns];
    return [self initWithNamespace:ns diskCacheDirectory:path];
}

- (id)initWithNamespace:(NSString *)ns diskCacheDirectory:(NSString *)directory {
    if ((self = [super init])) {
        NSString *fullNamespace = [@"com.hackemist.SDWebImageCache." stringByAppendingString:ns];
        
        // 根据kPNGSignatureBytes数组初始化PNG的署名数据
        kPNGSignatureData = [NSData dataWithBytes:kPNGSignatureBytes length:8];
        
        // 创建串行IO队列
        _ioQueue = dispatch_queue_create("com.hackemist.SDWebImageCache", DISPATCH_QUEUE_SERIAL);
        
        // 初始化默认的的缓存时长(一周)
        _maxCacheAge = kDefaultCacheMaxCacheAge;
        
        // 初始化内存缓存(NSCache)
        _memCache = [[YPAutoPurgeCache alloc] init];
        _memCache.name = fullNamespace;
        
        // Init the disk cache
        // 初始化沙盒缓存
        if (directory != nil) { // 如果指定了目录名
            // 拼接目录名和刚刚指定的文件夹名
            _diskCachePath = [directory stringByAppendingPathComponent:fullNamespace];
        } else { // 没有指定目录名
            // 根据命名空间建立在cache的根路径下
            NSString *path = [self makeDiskCachePath:ns];
            _diskCachePath = path;
        }
        
        // 默认为解压缩图片
        _shouldDecompressImages = YES;
        
        // 默认为使用内存缓存机制
        _shouldCacheImagesInMemory = YES;
        
        // 默认关闭iCloud备份
        _shouldDisableiCloud = YES;
        
        dispatch_sync(_ioQueue, ^{ // 在缓存队列中开启一个异步线程
            // 初始化文件管理者
            _fileManager = [[NSFileManager alloc] init];
        });
        
#if TARGET_OS_IPHONE
        // 订阅app事件
        // 当app接收到内存警告的时候调用clearMemory方法清除内存中的图片缓存
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        // 当app将要终止的时候调用cleanDisk清除沙盒中过期的图片缓存
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanDisk)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        // 当app进入后台的时候调用backgroundCleanDisk方法
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundCleanDisk)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
    // 移除所有监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 释放缓存队列
    YPDispatchQueueRelease(_ioQueue);
}

/**
 *  初始化沙盒缓存路径
 */
-(NSString *)makeDiskCachePath:(NSString*)fullNamespace{
    // 沙盒Caches路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:fullNamespace];
}

#pragma mark - ImageCache功能性方法 -
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(YPWebImageQueryCompletedBlock)doneBlock
{
    // 如果传入的block为空 直接返回nil
    if (!doneBlock) {
        return nil;
    }
    
    // 如果传入的key为空
    if (!key) {
        // 直接调用block,图片参数传nil,无缓存策略
        doneBlock(nil, YPImageCacheTypeNone);
        // 返回空
        return nil;
    }
    
    // 首先根据key从内存缓存中取图片(NSCache)
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) { // 如果内存中有图片
        // 回调doneBlock
        doneBlock(image, YPImageCacheTypeMemory);
        // 返回
        return nil;
    }
    
    // 如果内存缓存中没有图片 新建一个操作
    NSOperation *operation = [[NSOperation alloc] init];
    
    dispatch_async(self.ioQueue, ^{ // 开启一个异步线程
        if (operation.isCancelled) { // 如果操作被取消了直接返回
            return;
        }
        @autoreleasepool { // 因为是异步执行无法获取主线程的自动释放池需要手动添加
            // 根据key在沙盒缓存中读取这个图片
            UIImage *diskImage = [self diskImageForKey:key];
            if (diskImage && self.shouldCacheImagesInMemory) { // 如果沙盒中有图片并且内存缓存的开关为YES
                // 计算一下图片的缓存花费(容量)
                NSUInteger cost = YPCacheCostForImage(diskImage);
                // 将沙盒中读取的图片和key值以及图片缓存容量存到NSCache中
                [self.memCache setObject:diskImage forKey:key cost:cost];
            }
            dispatch_async(dispatch_get_main_queue(), ^{ // 回到主队列中执行
                // 调用doneBlock传入沙盒中读取的图片,以及缓存策略为从沙盒中读取
                doneBlock(diskImage, YPImageCacheTypeDisk);
            });
        }
    });
    // 返回刚才创建的空操作
    return operation;
}

/**
 *  从内存缓存中根据key读取对象
 */
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key {
    return [self.memCache objectForKey:key];
}

/**
 *  从沙盒中获取图片
 */
- (UIImage *)diskImageForKey:(NSString *)key {
    
    // 根据传入的key在沙盒中查找图片数据
    NSData *data = [self diskImageDataBySearchingAllPathsForKey:key];
    
    if (data) { // 如果有数据
        
        // 根据数据设置图片
        UIImage *image = [UIImage imageWithMultiFormatData:data];
        
        // 根据传入的key值重新设置图片的伸缩度
        image = [self scaledImageForKey:key image:image];
        
        if (self.shouldDecompressImages) { // 默认为YES
            // 对图片进行解码操作
            image = [UIImage decodedImageWithImage:image];
        }
        // 返回这个图片
        return image;
    } else { // 如果沙盒中没有数据直接返回nil
        return nil;
    }
}

/**
 *  根据传入的key值重新设置图片的伸缩度
 */
- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image {
    return YPScaledImageForKey(key, image);
}

/**
 *  根据传入的key在沙盒中查找图片数据
 */
- (NSData *)diskImageDataBySearchingAllPathsForKey:(NSString *)key {
    
    // 根据key得到默认的沙盒存储路径
    NSString *defaultPath = [self defaultCachePathForKey:key];
    
    // 从这个路径中读取数据
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    
    if (data) { // 如果有数据,返回数据
        return data;
    }
    
    // 如果没有数据,说明沙盒中没有缓存,搞一个自定义路径的数组
    NSArray *customPaths = [self.customPaths copy];
    for (NSString *path in customPaths) { // 遍历这个自定义数组
        // 根据这个数组中的路径和key生成新的文件缓存路径
        NSString *filePath = [self cachePathForKey:key inPath:path];
        // 从新的文件缓存路径中读取数据
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (imageData) { // 如果有图片数据就直接返回数据
            return imageData;
        }
    }
    
    return nil;

}

/**
 *  根据key得到默认的沙盒存储路径
 */
- (NSString *)defaultCachePathForKey:(NSString *)key {
    // 根据key与路径得到加密后的路径
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

/**
 *  根据key与路径得到加密后的路径
 */
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path {
    // 根据传入的Key对其进行MD5加密处理生成沙盒中缓存的路径
    NSString *filename = [self cachedFileNameForKey:key];
    // 将传入的路径拼接文件名返回
    return [path stringByAppendingPathComponent:filename];
}

// 清除内存缓存
- (void)clearMemory {
    [self.memCache removeAllObjects];
}
// 清除沙盒中过期的图片缓存
- (void)cleanDisk {
    [self cleanDiskWithCompletionBlock:nil];
}

// 清除沙盒中过期的图片缓存
- (void)cleanDiskWithCompletionBlock:(YPWebImageNoParamsBlock)completionBlock
{
    dispatch_async(self.ioQueue, ^{ // 首先在缓存队列中开启一个异步线程
        // 将沙盒缓存路径转化为URL
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        /**
         *  存储资源信息key的数组
         *  NSURLIsDirectoryKey : 主要用于确定资源是否是一个目录，返回一个布尔值的NSNumber对象
         *  NSURLContentModificationDateKey : 如果支持修改,这个值会返回一个NSData对象显示最近一次修改的日期,如果不支持修改那么这个值返回nil
         *  NSURLTotalFileAllocatedSizeKey : 用来表示文件的总大小,以字节为单位,返回NSNumber对象
         */
        NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        
        // 这个枚举可以从我们的缓存文件取出一些有用的属性
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL includingPropertiesForKeys:resourceKeys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        
        // 获取过期时间(从现在开始计算的前一周的时间)
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
        // 新建一个可变字典用来存储缓存文件
        NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
        // 声明一个当前缓存大小的变量 初始化为0
        NSUInteger currentCacheSize = 0;
        
        /**
         *  遍历所有的文件缓存目录。这个循环有两个目的:
         *  1.删除早于到期日期的文件
         *  2.存储以文件大小属性为基础的清除通道
         */
        
        // 新建一个可变数组用来存储过期的url
        NSMutableArray *urlsToDelete = [[NSMutableArray alloc] init];
        
        for (NSURL *fileURL in fileEnumerator) { // 遍历缓存文件资源信息枚举取出文件url
            // 根据文件url以及资源信息Key数组得到资源值字典
            NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
            
            // 跳过目录
            if ([resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }
            
            // 删除早于到期日期的文件
            
            // 1.获取文件的修改日期
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            // 2.看一下修改日期与过期日期谁比较晚,如果过期日期比较晚说明文件过期了
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                // 那么久将这个文件的url加入到过期数组里面去
                [urlsToDelete addObject:fileURL];
                // 跳过这次循环
                continue;
            }
            
            // 存储这个文件的引用 用来计算它的总大小
            
            // 获取资源总大小
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            // 将这个资源叠加到当前缓存容量值上
            currentCacheSize += [totalAllocatedSize unsignedIntegerValue];
            // 以文件url作为key 资源值字典作为对象存储到缓存文件字典中去
            [cacheFiles setObject:resourceValues forKey:fileURL];
        }
        
        for (NSURL *fileURL in urlsToDelete) { // 遍历这个过期url数组
            // 使用文件管理者移除过期的文件
            [_fileManager removeItemAtURL:fileURL error:nil];
        }
        
        /**
         *  如果设置了最大缓存，并且当前缓存的文件超过了这个限制，则删除最旧的文件，直到当前缓存文件的大小为最大缓存大小的一半
         */
        if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {
            
            // 目标缓存大小为最大缓存大小的一半
            const NSUInteger desiredCacheSize = self.maxCacheSize / 2;
            
            // 按缓存文件的修改时间排序,生成排序后的数组
            NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                            usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                            }];
            
            // 先删除最旧的文件
            for (NSURL *fileURL in sortedFiles) { // 遍历排序后的文件
                if ([_fileManager removeItemAtURL:fileURL error:nil]) { // 删除这个文件
                    // 如果删除成功,取出文件url键值对应的资源信息字典
                    NSDictionary *resourceValues = cacheFiles[fileURL];
                    // 取出资源信息中的文件大小
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    // 当前缓存总大小 -= 刚刚算出的文件大小
                    currentCacheSize -= [totalAllocatedSize unsignedIntegerValue];
                    
                    if (currentCacheSize < desiredCacheSize) { // 知道当前缓存的总大小小于目前缓存大小退出循环
                        break;
                    }
                }
            }
        }
        
        if (completionBlock) { // 回调完成的Block
            dispatch_async(dispatch_get_main_queue(), ^{
                // 在主队列中异步执行这个回调
                completionBlock();
            });
        }
        
    });
}
// 进入后台时清除沙河缓存策略
- (void)backgroundCleanDisk
{
    /**
     *  当UIApplication类不存在的时候直接返回
     */
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    
    // 获取UIApplication
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    
    // 向操作系统申请后台运行的资格，能维持多久，是不确定的
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // 当申请的后台运行时间已经结束（过期），就会调用这个block
        // 赶紧结束任务
        /**
         *  通过标记清理所有未完成的任务业务
         *  停止或结束任务
         */
        [application endBackgroundTask:bgTask];
        
        /**
         *  UIBackgroundTaskInvalid:一个标记，指示无效的任务要求。此常数应该用来初始化变量或以检查错误。
         */
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // 启动长时间运行的任务，并立即返回。
    [self cleanDiskWithCompletionBlock:^{ // 完成后立刻结束后台任务
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

/**
 *  重新计算转换的图像并缓存起来
 */
- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk
{
    if (!image || !key) { // 如果图像没有值或者key没有值直接返回
        return;
    }
    if (self.shouldCacheImagesInMemory) { // 如果内存缓存是可行的
        // 计算图片的缓存花费(容量)
        NSUInteger cost = YPCacheCostForImage(image);
        // 将图片缓存到NSCache中
        [self.memCache setObject:image forKey:key cost:cost];
    }
    
    if (toDisk) { // 如果沙盒缓存是可行的
        dispatch_async(self.ioQueue, ^{ // 根据缓存队列开启一个异步线程
            
            // 获取图像数据
            NSData *data = imageData;
            
            // 如果有图片并且
            // 图片被翻转了或者数据位空
            if (image && (recalculate || !data)) {
#if TARGET_OS_IPHONE // 当为Iphone时
                /**
                 *  我们需要确定图像是PNG还是JPEG
                 *  PNG类的图片更容易被检测,因为他们有独特的签名
                 *  第八位字节总是包含着以下的十进制数值: 137 80 78 71 13 10 26 10
                 *
                 *  如果图片数据为空（也就是说,如果想要直接保存UIImage或者在下载之后转换）
                 *  并且图像有一个alpha通道，我们会考虑它PNG，以避免失去透明度
                 */
                
                // 获取image的CGImageGetAlphaInfo
                int alphaInfo = CGImageGetAlphaInfo(image.CGImage);
                
                /**
                 *  当alphaInfo为以下枚举中的一种
                 *  kCGImageAlphaNone,kCGImageAlphaNoneSkipFirst,kCGImageAlphaNoneSkipLast
                 *  这个hasAlpha值为NO
                 */
                BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                                  alphaInfo == kCGImageAlphaNoneSkipFirst ||
                                  alphaInfo == kCGImageAlphaNoneSkipLast);
                // 根据这个BOOL值判断图片是否为PNG
                BOOL imageIsPng = hasAlpha;
                
                // But if we have an image data, we will look at the preffix
                // 但是如果我们有图片数据,我们将看一下前缀
                if ([imageData length] >= [kPNGSignatureData length]) { // 如果图片二进制数据的长度大于PNG的署名长度
                    // 根据数据的前缀判断图片是否为PNG
                    imageIsPng = ImageDataHasPNGPreffix(imageData);
                }
                
                if (imageIsPng) { // 如果图片是PNG图片
                    // 将图片以PNG格式解析成二进制数据
                    data = UIImagePNGRepresentation(image);
                }
                else { // 如果图片不是PNG图片
                    // 将图片以JPEG格式解析成二进制数据
                    data = UIImageJPEGRepresentation(image, (CGFloat)1.0);
                }
#endif
            }
            
            if (data) { // 如果有数据
                // 利用文件管理者查找一下沙盒缓存路径是否存在
                if (![_fileManager fileExistsAtPath:_diskCachePath]) { // 如果路径不存在
                    // 创建沙盒缓存路径
                    [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
                }
                
                // get cache Path for image key
                // 根据图片的key以及沙盒缓存路径获取默认的缓存路径
                NSString *cachePathForKey = [self defaultCachePathForKey:key];
                // transform to NSUrl
                // 将缓存路径字符串转换成NSUrl
                NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
                // 将图片数据保存到沙盒缓存路径上
                [_fileManager createFileAtPath:cachePathForKey contents:data attributes:nil];
                
                // disable iCloud backup 关闭iCloud备份
                if (self.shouldDisableiCloud) { // 如果不允许iCloud备份(默认不允许)
                    // 不采用备份设置
                    [fileURL setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
                    
                }
            }
        });
    }
}


#pragma mark  - SDImageCache (private) -
/**
 *  根据传入的Key对其进行MD5加密处理生成沙盒中缓存的路径
 *
 *  @param key url字符串
 */
- (NSString *)cachedFileNameForKey:(NSString *)key {
    // 将url字符串转换成字符数组
    const char *str = [key UTF8String];
    if (str == NULL) { // 如果为空
        str = ""; // 将str设置为""
    }
    /**
     *  #define CC_MD5_DIGEST_LENGTH    16
     *  开辟一个16字节（128位：md5加密出来就是128位/bit）的空间（一个字节=8字位=8个二进制数）
     */
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    /*
     extern unsigned char *CC_MD5(const void *data, CC_LONG len, unsigned char *md)官方封装好的加密方法
     把str字符串转换成了32位的16进制数列（这个过程不可逆转） 存储到了r这个空间中
     */
    CC_MD5(str, (CC_LONG)strlen(str), r);
    // 生成MD5加密后文件名
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
    // 返回MD5加密后文件名
    return filename;
}


@end





















