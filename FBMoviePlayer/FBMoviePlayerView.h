//
//  FBMoviePlayerView.h
//  TinyVideo
//
//  Created by FB on 2017/10/14.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FBVideoFrame;
@class FBMovieDecoder;

@interface FBMoviePlayerView : UIView

/**************************************
 *     initializer not avaliable      *
 **************************************/
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;


/**************************************
 *     initializer  avaliable         *
 **************************************/
- (instancetype)initWithFrame:(CGRect)frame decoder:(FBMovieDecoder*)decoder;

- (void)displayMovieFrame:(FBVideoFrame*)frame;

@end
