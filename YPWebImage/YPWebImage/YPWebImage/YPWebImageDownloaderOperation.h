//
//  YPWebImageDownloaderOperation.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YPWebImageDownloader.h"
#import "YPWebImageOperation.h"


@interface YPWebImageDownloaderOperation : NSOperation <YPWebImageOperation>

/** 是否解压缩图片 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 *  初始化SDWebImageDownloaderOperation对象
 *
 *  @param request        对url的请求
 *  @param completedBlock 完成的回调
 *  @param cancelBlock    取消的回调
 */
- (id)initWithRequest:(NSURLRequest *)request completed:(YPWebImageDownloaderCompletedBlock)completedBlock cancelled:(YPWebImageNoParamsBlock)cancelBlock;

@end
