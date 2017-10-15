//
//  UIImage+VideoThumb.m
//  TinyVideo
//
//  Created by FB on 2017/8/18.
//  Copyright © 2017年 FB. All rights reserved.
//

#import "UIImage+VideoThumb.h"

@implementation UIImage(VideoThumb)
/**
 *  获取网络视频的缩略图方法
 *
 *  @param videoURL 视频的链接地址
 *
 *  @return 视频截图
 */
+ (UIImage *)previewImageForRemoteVideoAtURLString:(NSString *)urlString
{
    if (!urlString || [urlString isEqualToString:@""]) {
        return nil;
    }
    
    AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:urlString]];
    
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    
    CGImageRef img = [generator copyCGImageAtTime:CMTimeMake(1, asset.duration.timescale) actualTime:NULL error:nil];
    UIImage *image = [UIImage imageWithCGImage:img];
    
    CGImageRelease(img);
    return image;
}
    
/**
 *  获取本地视频的全部缩略图方法
 *
 *  @param fileurl 视频的链接地址
 *
 *  @return 视频截图
 */
+ (UIImage *)previewImageForLocalVidelAtPath:(NSString *)filepath
{
    if (!filepath || [filepath isEqualToString:@""]) {
        return nil;
    }
    
    UIImage *shotImage;
    //视频路径URL
    NSURL *fileURL = [NSURL URLWithString:filepath];
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];
    
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    
    gen.appliesPreferredTrackTransform = YES;
    
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    
    NSError *error = nil;
    
    CMTime actualTime;
    
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    
    shotImage = [[UIImage alloc] initWithCGImage:image];
    
    CGImageRelease(image);
    
    return shotImage;
}


/**
 *  获取视频的某一帧缩略图方法
 *
 *  @param videoURL 视频的链接地址 帧时间
 *  @param time     帧时间
 *
 *  @return 视频截图
 */
+ (UIImage*)thumbnailImageForVideo:(NSString *)videoPath atTime:(NSTimeInterval)time
{
    if (!videoPath || [videoPath isEqualToString:@""]) {
        return nil;
    }
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL URLWithString:videoPath] options:nil];
    if (!asset) {
        return nil;
    }
    
    AVAssetImageGenerator *assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetImageGenerator.appliesPreferredTrackTransform = YES;
    assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time;
    NSError *thumbnailImageGenerationError = nil;
    thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60) actualTime:NULL error:&thumbnailImageGenerationError];
    
    UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc] initWithCGImage:thumbnailImageRef] : nil;
    
    return thumbnailImage;
}
@end
