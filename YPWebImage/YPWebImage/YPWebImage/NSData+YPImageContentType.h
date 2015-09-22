//
//  NSData+YPImageContentType.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (YPImageContentType)

/**
 *  根据图片数据计算图片的内容类型
 *
 *  @param data 数据
 */
+ (NSString *)contentTypeForImageData:(NSData *)data;

@end
