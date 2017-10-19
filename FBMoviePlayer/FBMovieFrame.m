//
//  FBMovieFrame.m
//  TinyVideo
//
//  Created by FB on 2017/10/16.
//  Copyright © 2017年 FB. All rights reserved.
//

#import "FBMovieFrame.h"

@implementation FBMovieFrame
@end

@implementation FBAudioFrame

- (FBMovieFrameType) type {
    return FBMovieFrameTypeAudio;
}
@end


@implementation FBVideoFrame

- (FBMovieFrameType) type {
    return FBMovieFrameTypeVideo;
}
@end


@implementation FBVideoFrameRGB

- (FBVideoFrameFormat) format {
    return FBVideoFrameFormatRGB;
}

- (UIImage *) asImage {
    UIImage *image = nil;
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(_rgb));
    if (provider) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        if (colorSpace) {
            CGImageRef imageRef = CGImageCreate(self.width,
                                                self.height,
                                                8,
                                                24,
                                                self.linesize,
                                                colorSpace,
                                                kCGBitmapByteOrderDefault,
                                                provider,
                                                NULL,
                                                YES, // NO
                                                kCGRenderingIntentDefault);
            
            if (imageRef) {
                image = [UIImage imageWithCGImage:imageRef];
                CGImageRelease(imageRef);
            }
            CGColorSpaceRelease(colorSpace);
        }
        CGDataProviderRelease(provider);
    }
    
    return image;
}
@end


@implementation FBVideoFrameYUV

- (FBVideoFrameFormat) format {
    return FBVideoFrameFormatYUV;
}
@end


@implementation FBArtworkFrame

- (FBMovieFrameType) type {
    return FBMovieFrameTypeArtwork;
}

- (UIImage *) asImage {
    UIImage *image = nil;
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(_picture));
    if (provider) {
        
        CGImageRef imageRef = CGImageCreateWithJPEGDataProvider(provider,
                                                                NULL,
                                                                YES,
                                                                kCGRenderingIntentDefault);
        if (imageRef) {
            
            image = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        }
        CGDataProviderRelease(provider);
    }
    
    return image;
    
}
@end


@implementation FBSubtitleFrame

- (FBMovieFrameType) type {
    return FBMovieFrameTypeSubtitle;
}
@end
