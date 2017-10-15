//
//  UIImage+VideoThumb.h
//  TinyVideo
//
//  Created by FB on 2017/8/18.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIImage(VideoThumb)
    
/**
 *  获取网络视频的缩略图方法
 *
 *  @param videoURL 视频的链接地址
 *
 *  @return 视频截图
 */
+ (UIImage *)previewImageForRemoteVideoAtURLString:(NSString *)urlString;
    
    
/**
 *  获取本地视频的全部缩略图方法
 *
 *  @param fileurl 视频的链接地址
 *
 *  @return 视频截图
 */
+ (UIImage *)previewImageForLocalVidelAtPath:(NSString *)filepath;
    

/**
 *  获取视频的某一帧缩略图方法
 *
 *  @param videoURL 视频的链接地址 帧时间
 *  @param time     帧时间
 *
 *  @return 视频截图
 */
+ (UIImage*)thumbnailImageForVideo:(NSString *)videoPath atTime:(NSTimeInterval)time;
@end
