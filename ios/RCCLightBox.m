#import "RCCLightBox.h"
#import "RCCManager.h"
#import <React/RCTRootView.h>
#import <React/RCTRootViewDelegate.h>
#import <React/RCTConvert.h>
#import <React/RCTUtils.h>
#import <React/RCTEventDispatcher.h>
#import "RCTHelpers.h"
#import <objc/runtime.h>

const NSInteger kLightBoxTag = 0x101010;

@interface RCCLightBoxView : UIView<UIGestureRecognizerDelegate>
@property (nonatomic, strong) RCTRootView *reactView;
@property (nonatomic, strong) UIVisualEffectView *visualEffectView;
@property (nonatomic, strong) UIView *overlayColorView;
@property (nonatomic, strong) NSDictionary *params;
@property (nonatomic)         BOOL yellowBoxRemoved;
@property (nonatomic)         BOOL isDismissing;
@end

@implementation RCCLightBoxView

-(instancetype)initWithFrame:(CGRect)frame params:(NSDictionary*)params
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        self.params = params;
        self.yellowBoxRemoved = NO;
        
        NSDictionary *passProps = self.params[@"passProps"];
        
        NSDictionary *style = self.params[@"style"];
        if (self.params != nil && style != nil)
        {
            
            if (style[@"backgroundBlur"] != nil && ![style[@"backgroundBlur"] isEqualToString:@"none"])
            {
                self.visualEffectView = [[UIVisualEffectView alloc] init];
                self.visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                self.visualEffectView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
                [self addSubview:self.visualEffectView];
            }
            
            if (style[@"backgroundColor"] != nil)
            {
                UIColor *backgroundColor = [RCTConvert UIColor:style[@"backgroundColor"]];
                if (backgroundColor != nil)
                {
                    self.overlayColorView = [[UIView alloc] init];
                    self.overlayColorView.backgroundColor = backgroundColor;
                    self.overlayColorView.alpha = 0;
                    [self.overlayColorView setTranslatesAutoresizingMaskIntoConstraints:NO];
                    [self addSubview:self.overlayColorView];
                }
            }
            
            if (style[@"tapBackgroundToDismiss"] != nil && [RCTConvert BOOL:style[@"tapBackgroundToDismiss"]])
            {
                UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissAnimated)];
                singleTap.delegate = self;
                [self addGestureRecognizer:singleTap];
            }
        }
        
        [self setupReactViewWithStyle:style passProps:passProps];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRNReload) name:RCTJavaScriptWillStartLoadingNotification object:nil];
    }
    return self;
}

-(void)setupReactViewWithStyle:(NSDictionary*)style passProps:(NSDictionary*)passProps
{
    self.reactView = [[RCTRootView alloc] initWithBridge:[[RCCManager sharedInstance] getBridge] moduleName:self.params[@"component"] initialProperties:passProps];
    
    if ([RCTConvert BOOL:style[@"requiresFullScreen"]]) {
        [self.reactView setTranslatesAutoresizingMaskIntoConstraints:NO];
    } else {
        self.reactView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        self.reactView.sizeFlexibility = RCTRootViewSizeFlexibilityWidthAndHeight;
        self.reactView.center = self.center;
    }
    
    self.reactView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.reactView];
    
    [self.reactView.contentView.layer addObserver:self forKeyPath:@"frame" options:0 context:nil];
    [self.reactView.contentView.layer addObserver:self forKeyPath:@"bounds" options:0 context:NULL];
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ![touch.view isDescendantOfView:self.reactView];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    
    self.reactView.frame = self.bounds;
    self.overlayColorView.frame = self.bounds;
    
    if(!self.yellowBoxRemoved)
    {
        self.yellowBoxRemoved = [RCTHelpers removeYellowBox:self.reactView];
    }
}

-(void)removeAllObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.reactView.contentView.layer removeObserver:self forKeyPath:@"frame" context:nil];
    [self.reactView.contentView.layer removeObserver:self forKeyPath:@"bounds" context:NULL];
}

-(void)dealloc
{
    [self removeAllObservers];
}

-(void)onRNReload
{
    [self removeAllObservers];
    [self removeFromSuperview];
    self.reactView = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    CGSize frameSize = CGSizeZero;
    if ([object isKindOfClass:[CALayer class]])
        frameSize = ((CALayer*)object).frame.size;
    if ([object isKindOfClass:[UIView class]])
        frameSize = ((UIView*)object).frame.size;
    
    if (!CGSizeEqualToSize(frameSize, self.reactView.frame.size))
    {
        self.reactView.frame = CGRectMake((self.frame.size.width - frameSize.width) * 0.5, (self.frame.size.height - frameSize.height) * 0.5, frameSize.width, frameSize.height);
    }
}

-(UIBlurEffect*)blurEfectForCurrentStyle
{
    NSDictionary *style = self.params[@"style"];
    NSString *backgroundBlur = style[@"backgroundBlur"];
    if ([backgroundBlur isEqualToString:@"none"])
    {
        return nil;
    }
    
    UIBlurEffectStyle blurEffectStyle = UIBlurEffectStyleDark;
    if ([backgroundBlur isEqualToString:@"light"])
        blurEffectStyle = UIBlurEffectStyleLight;
    else if ([backgroundBlur isEqualToString:@"xlight"])
        blurEffectStyle = UIBlurEffectStyleExtraLight;
    else if ([backgroundBlur isEqualToString:@"dark"])
        blurEffectStyle = UIBlurEffectStyleDark;
    return [UIBlurEffect effectWithStyle:blurEffectStyle];
}

-(void)showAnimated
{
    [self sendScreenChangedEvent:@"willAppear"];
    
    if (self.visualEffectView != nil || self.overlayColorView != nil)
    {
        [UIView animateWithDuration:0.3 animations:^()
         {
             if (self.visualEffectView != nil)
             {
                 self.visualEffectView.effect = [self blurEfectForCurrentStyle];
             }
             
             if (self.overlayColorView != nil)
             {
                 self.overlayColorView.alpha = 1;
             }
         }];
    }
    
    self.reactView.transform = CGAffineTransformMakeTranslation(0, 100);
    self.reactView.alpha = 0;
    [UIView animateWithDuration:0.6 delay:0.2 usingSpringWithDamping:0.65 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^()
     {
         self.reactView.transform = CGAffineTransformIdentity;
         self.reactView.alpha = 1;
         [self sendScreenChangedEvent:@"didAppear"];
     } completion:nil];
}

-(void)dismissAnimated
{
    self.isDismissing = YES;
    [self sendScreenChangedEvent:@"willDisappear"];
    
    BOOL hasOverlayViews = (self.visualEffectView != nil || self.overlayColorView != nil);
    
    [UIView animateWithDuration:0.2 animations:^()
     {
         self.reactView.transform = CGAffineTransformMakeTranslation(0, 80);
         self.reactView.alpha = 0;
     }
                     completion:^(BOOL finished)
     {
         if (!hasOverlayViews)
         {
             [self sendScreenChangedEvent:@"didDisappear"];
             [self removeFromSuperview];
         }
     }];
    
    if (hasOverlayViews)
    {
        [UIView animateWithDuration:0.25 delay:0.15 options:UIViewAnimationOptionCurveEaseOut animations:^()
         {
             if (self.visualEffectView != nil)
             {
                 self.visualEffectView.effect = nil;
             }
             
             if (self.overlayColorView != nil)
             {
                 self.overlayColorView.alpha = 0;
             }
             
         } completion:^(BOOL finished)
         {
             [self sendScreenChangedEvent:@"didDisappear"];
             [self removeFromSuperview];
         }];
    }
}

- (void)sendScreenChangedEvent:(NSString *)eventName
{
    if (self.reactView && self.reactView.appProperties[@"navigatorEventID"]) {
        
        [[[RCCManager sharedInstance] getBridge].eventDispatcher sendAppEventWithName:self.reactView.appProperties[@"navigatorEventID"] body:@
         {
             @"type": @"ScreenChangedEvent",
             @"id": eventName
         }];
    }
}

@end

@implementation RCCLightBox

+(void)showWithParams:(NSDictionary*)params
{
    UIViewController *viewController = RCTPresentedViewController();
    RCCLightBoxView *previousLightBox = [viewController.view viewWithTag:kLightBoxTag];
    if (previousLightBox != nil && !previousLightBox.isDismissing)
    {
        return;
    }
    
    RCCLightBoxView *lightBox = [[RCCLightBoxView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) params:params];
    lightBox.tag = kLightBoxTag;
    [viewController.view addSubview:lightBox];
    [lightBox showAnimated];
}

+(void)dismiss
{
    UIViewController *viewController = RCTPresentedViewController();
    RCCLightBoxView *lightBox = [viewController.view viewWithTag:kLightBoxTag];
    if (lightBox != nil)
    {
        [lightBox dismissAnimated];
    }
}

@end
