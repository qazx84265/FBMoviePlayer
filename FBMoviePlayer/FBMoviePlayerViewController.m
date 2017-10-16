//
//  FBMoviePlayerViewController.m
//  TinyVideo
//
//  Created by FB on 2017/10/14.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>

#import "FBMoviePlayerViewController.h"
#import "FBMoviePlayer.h"
#import "FBMovieDefs.h"


typedef NS_ENUM(NSInteger, PanDirection){
    PanDirectionHorizontalMoved, // 横向移动
    PanDirectionVerticalMoved    // 纵向移动
};

static void* kvo_player_ctx = &kvo_player_ctx;

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





@interface FBMoviePlayerViewController () {
    CGFloat _lastPostion;
    CGFloat _lastProgress;
    
    NSString *_moviePath;
}

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

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;

@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;


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

+ (instancetype)moviePlayerWithMovie:(NSString *)moviePath {
    return [[FBMoviePlayerViewController alloc] initWithMovie:moviePath];
}

- (instancetype)initWithMovie:(NSString *)moviePath {
    if (self = [super init]) {
        _moviePath = moviePath;
    }
    
    return self;
}

#pragma mark -- ui
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
//    if (self.player && !self.player.isPlaying) {
//        [self.player play];
//    }
    
//    [self.activityIndicatorView startAnimating];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
//    [self.activityIndicatorView stopAnimating];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    // Do any additional setup after loading the view.
    
    _lastPostion = 0;
    _lastProgress = 0;
    
    
    [self setUI];
    
    [self setPlayer];
        
    
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
    self.playTimeLabel.text = @"00:00";
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
    self.playSlider.continuous = NO;
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
    
    self.activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
    self.activityIndicatorView.center = self.view.center;
    [self.view addSubview:self.activityIndicatorView];
    
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
    NSAssert(_moviePath, @"movie path should not be nil");
    
    self.player = [FBMoviePlayer playerWithMovie:_moviePath];
    [self.view insertSubview:self.player.playerView atIndex:0];
    [self.player.playerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(self.view);
    }];
    
    //
    [self setupUserInteraction];
    
    [self addNotis];
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



#pragma mark -- actions
- (void)close:(UIButton*)sender {
    if (self.presentingViewController || !self.navigationController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else {
        [self.navigationController popViewControllerAnimated:YES];
    }
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
    if (!self.player.isPlaying ||
        self.player.movieDuration == 0 ||
        self.player.movieDuration == MAXFLOAT) {
        return;
    }
    
    [self.player setMoviePosition:self.player.playedPosition - 5];
}

- (void)forward:(UIButton*)sender {
    if (!self.player.isPlaying ||
        self.player.movieDuration == 0 ||
        self.player.movieDuration == MAXFLOAT) {
        return;
    }
    
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
                                             selector:@selector(playComplete:) name:kMoviePlayerDidCompletedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(beginToBuff:) name:kMoviePlayerBeginBuffNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(endToBuff:) name:kMoviePlayerEndBuffNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
    
    [self.player addObserver:self forKeyPath:@"playedPosition" options:NSKeyValueObservingOptionNew context:kvo_player_ctx];
    [self.player addObserver:self forKeyPath:@"movieDuration" options:NSKeyValueObservingOptionNew context:kvo_player_ctx];
//    [self.player addObserver:self forKeyPath:@"playingProgress" options:NSKeyValueObservingOptionNew context:kvo_player_ctx];
}

- (void)removeNotis {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.player removeObserver:self forKeyPath:@"playedPosition"];
    [self.player removeObserver:self forKeyPath:@"movieDuration"];
//    [self.player removeObserver:self forKeyPath:@"playingProgress"];
}

- (void) applicationWillResignActive: (NSNotification *)notification {
    
    NSLog(@"----->>>>>>>> applicationWillResignActive");
    [self.player pause];
}

- (void)playComplete:(NSNotification*)notification {
    NSLog(@"----->>>>>>>> playComplete");
    
    weakify(self)
    fbmovie_gcd_main_async_safe(^{
        strongify(self)
        _lastProgress = 0;
        _lastPostion = 0;
        
        [self updatePlayButton];
        [self.activityIndicatorView stopAnimating];
    })
}

- (void)beginToBuff:(NSNotification*)notification {
    NSLog(@"----->>>>>>>> playComplete");
    
    weakify(self)
    fbmovie_gcd_main_async_safe(^{
        strongify(self)
        [self.activityIndicatorView startAnimating];
    })
}

- (void)endToBuff:(NSNotification*)notification {
    NSLog(@"----->>>>>>>> playComplete");
    
    weakify(self)
    fbmovie_gcd_main_async_safe(^{
        strongify(self)
        [self.activityIndicatorView stopAnimating];
    })
}



#pragma mark -- kvo
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == kvo_player_ctx) {
        weakify(self)
        
        if ([keyPath isEqualToString:@"playingProgress"]) {
            CGFloat pro = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
            if ((pro - _lastProgress) >= 0.01) {
                fbmovie_gcd_main_async_safe(^{
                    strongify(self)
                    self.playSlider.value = pro;
                    _lastProgress = pro;
                })
            }
        }
        else if ([keyPath isEqualToString:@"movieDuration"]) {
            CGFloat dur = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
            //NSLog(@"--------->>>>>>>>>>> %f", pos);
            if (dur >0 && dur != MAXFLOAT) {
                fbmovie_gcd_main_async_safe(^{
                    strongify(self)
                    self.durationTimeLabel.text = formatTimeInterval(dur);
                })
            }
        }
        else if ([keyPath isEqualToString:@"playedPosition"]) {
            CGFloat pos = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
            //NSLog(@"--------->>>>>>>>>>> %f", pos);
            if ((pos - _lastPostion) >= 1.0) {
                fbmovie_gcd_main_async_safe(^{
                    strongify(self)
                    self.playTimeLabel.text = formatTimeInterval(pos);
                    _lastPostion = pos;
                })
            }
            
            if (self.player.movieDuration > 0 && self.player.movieDuration != MAXFLOAT) {
                CGFloat pro = pos / self.player.movieDuration;
                if (pro - _lastProgress >= 0.01) {
                    fbmovie_gcd_main_async_safe(^{
                        strongify(self)
                        self.playSlider.value = pro;
                        _lastProgress = pro;
                    })
                }
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
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
