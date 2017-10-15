//
//  FBMoviePlayerViewController.m
//  TinyVideo
//
//  Created by FB on 2017/10/14.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>

#import "FBMoviePlayerViewController.h"

#import "FBMovieDecoder.h"
#import "FBMoviePlayerView.h"

#import "FBMoviePlayer.h"

typedef NS_ENUM(NSInteger, PanDirection){
    PanDirectionHorizontalMoved, // 横向移动
    PanDirectionVerticalMoved    // 纵向移动
};

static NSString * formatTimeInterval(CGFloat seconds) {
    seconds = MAX(0, seconds);
    
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;
    
    NSString *format;
    if (h != 0) {
        format = [NSString stringWithFormat:@"%0.2zd:%0.2zd:%0.2zd", h, m, s];
    }
    else {
        format = [NSString stringWithFormat:@"%0.2zd:%0.2zd", m, s];
    }
    
    return format;
}

@interface FBMoviePlayerViewController ()
@property (nonatomic, strong) FBMovieDecoder *decoder;
@property (nonatomic, strong) FBMoviePlayerView *preview;

@property (nonatomic, strong) FBMoviePlayer *player;


// ui
@property (nonatomic, strong) UIVisualEffectView *topLeftHUD;
@property (nonatomic, strong) UIVisualEffectView *bottomHUD;

@property (nonatomic, strong) UILabel *playTimeLabel;
@property (nonatomic, strong) UILabel *durationTimeLabel;
@property (nonatomic, strong) UISlider *playSlider;
@property (nonatomic, strong) UIProgressView *playProcessView;

@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *rewindButton;
@property (nonatomic, strong) UIButton *forwardButton;

@property (nonatomic, strong) UIButton *fullScreenButton;
@property (nonatomic, strong) UIButton *closeButton;

// 系统音量slider
@property (nonatomic, strong) UISlider *volumeViewSlider;

@property (nonatomic, strong)UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, strong)UIPanGestureRecognizer *panGestureRecognizer;


/** 用来保存手势滑动快进的总时长 */
@property (nonatomic, assign) CGFloat                sumTime;
/** 定义一个实例变量，保存枚举值 */
@property (nonatomic, assign) PanDirection           panDirection;
/** 是否锁定屏幕方向 */
@property (nonatomic, assign) BOOL                   isLocked;
/** 是否在调节音量*/
@property (nonatomic, assign) BOOL                   isVolume;

@end

@implementation FBMoviePlayerViewController

#pragma mark -- ui
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
//    if (self.player && !self.player.isPlaying) {
//        [self.player play];
//    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    // Do any additional setup after loading the view.
    
    [self setUI];
    
    [self setPlayer];
    
    [self addNotis];
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTime:) userInfo:nil repeats:YES];
    
    
    //NSLog(@"------>>>>>>>>>> view size : %@", NSStringFromCGSize(self.player.playerView.size));
}

- (void)setUI {
    // top left
    self.topLeftHUD = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    self.topLeftHUD.alpha = 0.8;
    self.topLeftHUD.layer.cornerRadius = 10;
    self.topLeftHUD.layer.masksToBounds = YES;
    [self.view addSubview:self.topLeftHUD];
    
    self.closeButton = [[UIButton alloc] init];
    [self.closeButton setImage:[UIImage imageNamed:@"fbmp.bundle/player_close"] forState:UIControlStateNormal];
    self.closeButton.backgroundColor = [UIColor clearColor];
    [self.closeButton addTarget:self action:@selector(close:) forControlEvents:UIControlEventTouchUpInside];
    [self.topLeftHUD.contentView addSubview:self.closeButton];
    
    // bottom
    self.bottomHUD = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    self.bottomHUD.alpha = 0.8;
    self.bottomHUD.layer.cornerRadius = 15;
    self.bottomHUD.layer.masksToBounds = YES;
    [self.view addSubview:self.bottomHUD];
    
    self.playTimeLabel = [[UILabel alloc] init];
    self.playTimeLabel.textColor = [UIColor whiteColor];
    self.playTimeLabel.backgroundColor = [UIColor clearColor];
    self.playTimeLabel.font = [UIFont systemFontOfSize:11.0];
    [self.bottomHUD.contentView addSubview:self.playTimeLabel];
    
    self.durationTimeLabel = [[UILabel alloc] init];
    self.durationTimeLabel.textColor = [UIColor whiteColor];
    self.durationTimeLabel.font = [UIFont systemFontOfSize:11.0];
    self.durationTimeLabel.textAlignment = NSTextAlignmentRight;
    [self.bottomHUD.contentView addSubview:self.durationTimeLabel];
    
    self.playProcessView = [[UIProgressView alloc] init];
    self.playProcessView.progressTintColor = [UIColor whiteColor];
    self.playProcessView.trackTintColor = [UIColor lightGrayColor];
    [self.bottomHUD.contentView addSubview:self.playProcessView];
    
    self.playSlider = [[UISlider alloc] init];
    self.playSlider.minimumTrackTintColor = [UIColor whiteColor];
    self.playSlider.maximumTrackTintColor = [UIColor clearColor];
    [self.playSlider setThumbImage:[UIImage imageWithColor:[UIColor whiteColor] size:CGSizeMake(10, 10)] forState:UIControlStateNormal];
    [self.playSlider addTarget:self action:@selector(progressChanged:) forControlEvents:UIControlEventValueChanged];
    [self.bottomHUD.contentView addSubview:self.playSlider];
    
    self.playButton = [[UIButton alloc] init];
    [self.playButton setImage:[UIImage imageNamed:@"fbmp.bundle/player_play"] forState:UIControlStateNormal];
    self.playButton.backgroundColor = [UIColor clearColor];
    [self.playButton addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomHUD.contentView addSubview:self.playButton];
    
    self.rewindButton = [[UIButton alloc] init];
    [self.rewindButton setImage:[UIImage imageNamed:@"fbmp.bundle/player_rewind"] forState:UIControlStateNormal];
    self.rewindButton.backgroundColor = [UIColor clearColor];
    [self.rewindButton addTarget:self action:@selector(rewind:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomHUD.contentView addSubview:self.rewindButton];
    
    self.forwardButton = [[UIButton alloc] init];
    [self.forwardButton setImage:[UIImage imageNamed:@"fbmp.bundle/player_forward"] forState:UIControlStateNormal];
    self.forwardButton.backgroundColor = [UIColor clearColor];
    [self.forwardButton addTarget:self action:@selector(forward:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomHUD.contentView addSubview:self.forwardButton];
    
    self.fullScreenButton = [[UIButton alloc] init];
    [self.fullScreenButton setImage:[UIImage imageNamed:@"fbmp.bundle/player_fullscreen"] forState:UIControlStateNormal];
    self.fullScreenButton.backgroundColor = [UIColor clearColor];
    [self.fullScreenButton addTarget:self action:@selector(fullScreen:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomHUD.contentView addSubview:self.fullScreenButton];
    
    //-- set constraits
    [self.topLeftHUD mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left).offset(5);
        make.top.equalTo(self.view).offset(20);
        make.height.equalTo(@40);
        make.width.equalTo(@60);
    }];
    
    [self.closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@35);
        make.center.equalTo(self.topLeftHUD.contentView);
    }];
    
    
    [self.bottomHUD mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(5);
        make.bottom.right.equalTo(self.view).offset(-5);
        make.height.equalTo(@100);
    }];
    
    [self.playTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.playSlider.mas_left).offset(0);
        make.top.equalTo(self.playSlider.mas_bottom).offset(-5);
    }];
    
    [self.playSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@20);
        make.left.equalTo(self.bottomHUD.contentView.mas_left).offset(10);
        make.centerX.equalTo(self.bottomHUD.contentView.mas_centerX);
        make.top.equalTo(self.bottomHUD.contentView.mas_top).offset(10);
    }];
    
    [self.playProcessView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.playSlider);
        make.centerY.equalTo(self.playSlider.mas_centerY);
    }];
    
    [self.durationTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.playSlider.mas_right).offset(0);
        make.centerY.equalTo(self.playTimeLabel.mas_centerY);
    }];
    
    [self.playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@35);
        make.centerX.equalTo(self.bottomHUD.contentView.mas_centerX);
        make.top.equalTo(self.playTimeLabel.mas_bottom).offset(10);
    }];
    
    [self.rewindButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(self.playButton);
        make.centerY.equalTo(self.playButton.mas_centerY);
        make.right.equalTo(self.playButton.mas_left).offset(-30);
    }];
    
    [self.forwardButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(self.playButton);
        make.centerY.equalTo(self.playButton.mas_centerY);
        make.left.equalTo(self.playButton.mas_right).offset(30);
    }];
    
    [self.fullScreenButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(self.playButton);
        make.centerY.equalTo(self.playButton.mas_centerY);
        make.right.equalTo(self.bottomHUD.contentView.mas_right).offset(-10);
    }];
    
}

//- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
//    NSLog(@"------>>>>>>>>>> viewWillTransitionToSize : %@", NSStringFromCGSize(size));
//}


/**
 *  get system volume slider
 */
- (void)configureVolume {
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    _volumeViewSlider = nil;
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _volumeViewSlider = (UISlider *)view;
            break;
        }
    }
    
//    // 使用这个category的应用不会随着手机静音键打开而静音，可在手机静音下播放声音
//    NSError *setCategoryError = nil;
//    BOOL success = [[AVAudioSession sharedInstance]
//                    setCategory: AVAudioSessionCategoryPlayback
//                    error: &setCategoryError];
//
//    if (!success) { /* handle the error in setCategoryError */ }
    
}

- (void)setPlayer {
    
    NSString* path = @"http://sc1.111ttt.com/2017/1/05/09/298092036393.mp3";//@"rtmp://live.hkstv.hk.lxdns.com/live/hks";//[[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];//
    
    self.player = [FBMoviePlayer playerWithMovie:path];
    [self.view insertSubview:self.player.playerView atIndex:0];
    [self.player.playerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(self.view);
    }];
    
    //
    [self setupUserInteraction];
}

- (void) setupUserInteraction {
    
    self.player.playerView.userInteractionEnabled = YES;
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    self.tapGestureRecognizer.numberOfTapsRequired = 1;
    
//    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
//
//    [self.tapGestureRecognizer requireGestureRecognizerToFail:self.panGestureRecognizer];
    
//    [self.player.playerView addGestureRecognizer:self.panGestureRecognizer];
    [self.player.playerView addGestureRecognizer:self.tapGestureRecognizer];
    
}

#pragma mark - gesture recognizer

- (void) handleTap: (UITapGestureRecognizer *) sender {
    
    [UIView animateWithDuration:0.3 animations:^{
        self.topLeftHUD.hidden = !self.topLeftHUD.isHidden;
        self.bottomHUD.hidden = !self.bottomHUD.isHidden;
    } completion:^(BOOL finished) {
        
    }];
}

- (void)panDirection:(UIPanGestureRecognizer *)pan {
    CGPoint locationPoint = [pan locationInView:self.player.playerView];
    
    CGPoint veloctyPoint = [pan velocityInView:self.player.playerView];
    
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{ //
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            if (x > y) { //
                self.panDirection = PanDirectionHorizontalMoved;
                // TODO://
                //...
            }
            else if (x < y){ //
                self.panDirection = PanDirectionVerticalMoved;
                if (locationPoint.x > self.player.playerView.bounds.size.width / 2) {
                    self.isVolume = YES;
                }else { //
                    self.isVolume = NO;
                }
            }
            break;
        }
        case UIGestureRecognizerStateChanged:{ //
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    [self horizontalMoved:veloctyPoint.x]; //
                    break;
                }
                case PanDirectionVerticalMoved:{
                    [self verticalMoved:veloctyPoint.y]; //
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:{ //
            //
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    
                    self.sumTime = 0;
                    break;
                }
                case PanDirectionVerticalMoved:{
                    self.isVolume = NO;
                    break;
                }
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
}


- (void)verticalMoved:(CGFloat)value {
    self.isVolume ? (self.volumeViewSlider.value -= value / 10000) : ([UIScreen mainScreen].brightness -= value / 10000);
}

- (void)horizontalMoved:(CGFloat)value {
    // sum
    self.sumTime += value / 200;
    
}



#pragma mark -- timer
- (void)updateTime:(NSTimer*)timer {
    CGFloat position = self.player.playedPosition;
    CGFloat duration = self.player.movieDuration;
    
    self.playTimeLabel.text = formatTimeInterval(position);
    
    if (duration > 0 && duration != MAXFLOAT) {
        self.durationTimeLabel.text = formatTimeInterval(duration - position);
        self.playSlider.value = position / duration;
    }
//    else {
//        self.durationTimeLabel.text = @"--:--";
//    }
}


#pragma mark -- actions
- (void)close:(UIButton*)sender {
    
}

- (void)play:(UIButton*)sender {
    if (self.player.isPlaying) {
        [self.player pause];
    }
    else {
        [self.player play];
    }
    
    [self updatePlayButton];
}

- (void)rewind:(UIButton*)sender {
    [self.player setMoviePosition:self.player.playedPosition - 5];
}

- (void)forward:(UIButton*)sender {
    [self.player setMoviePosition:self.player.playedPosition + 5];
}

- (void)fullScreen:(UIButton*)sender {
    
}

- (void)progressChanged:(UISlider*)slider {
    if (!self.player.isPlaying ||
        self.player.movieDuration == 0 ||
        self.player.movieDuration == MAXFLOAT) {
        return;
    }
    
    [self.player setMoviePosition:slider.value * self.player.movieDuration];
}

- (void)updatePlayButton {
    [self.playButton setImage:[UIImage imageNamed:self.player.isPlaying ? @"fbmp.bundle/player_pause" : @"fbmp.bundle/player_play"] forState:UIControlStateNormal];
}

#pragma mark -- noti
- (void)addNotis {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

- (void)removeNotis {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) applicationWillResignActive: (NSNotification *)notification {
    
    [self.player pause];
    
    NSLog(@"----->>>>>>>> applicationWillResignActive");
}


#pragma mark -- memory
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [self removeNotis];
}

@end
