//
//  FBMovieFrame.h
//  TinyVideo
//
//  Created by FB on 2017/10/16.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 * video frame pixel format extract from ffmpeg
 */
typedef NS_ENUM(NSInteger, FBMovieFrameType) {
    FBMovieFrameTypeVideo,
    FBMovieFrameTypeAudio,
    FBMovieFrameTypeArtwork,
    FBMovieFrameTypeSubtitle
};

/**
 * video frame pixel format extract from ffmpeg
 */
typedef NS_ENUM(NSInteger, FBVideoFrameFormat) {
    FBVideoFrameFormatRGB,
    FBVideoFrameFormatYUV
};


@interface FBMovieFrame : NSObject
@property (nonatomic, assign, readonly) FBMovieFrameType type;
@property (nonatomic, assign) CGFloat position;
@property (nonatomic, assign) CGFloat duration;
@end

@interface FBAudioFrame : FBMovieFrame
@property (nonatomic, strong) NSData *samples;
@end

@interface FBVideoFrame : FBMovieFrame
@property (nonatomic, assign, readonly) FBVideoFrameFormat format;
@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;
@end

@interface FBVideoFrameRGB : FBVideoFrame
@property (nonatomic, assign) NSUInteger linesize;
@property (nonatomic, strong) NSData *rgb;
- (UIImage *) asImage;
@end

@interface FBVideoFrameYUV : FBVideoFrame
@property (nonatomic, strong) NSData *luma;
@property (nonatomic, strong) NSData *chromaB;
@property (nonatomic, strong) NSData *chromaR;
@end

@interface FBArtworkFrame : FBMovieFrame
@property (nonatomic, strong) NSData *picture;
- (UIImage *) asImage;
@end

@interface FBSubtitleFrame : FBMovieFrame
@property (nonatomic, copy) NSString *text;
@end
