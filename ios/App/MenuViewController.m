// Pick a game, in the same pixel-art style as the controls (art drawn by ci/menu_art.py).
// Each game gets its own save folder: Documents/<game>/ (visible in the Files app).
#import "MenuViewController.h"
#import <GameController/GameController.h>
#import "GameViewController.h"
#import "Sunky.h"

// ---- Pixel text: draws strings from the 7x9-cell font strips (ASCII 32..95) ----

static UIImage *controlImage(NSString *name) {
    NSString *path = [NSBundle.mainBundle pathForResource:name ofType:@"png" inDirectory:@"Controls"];
    return path ? [UIImage imageWithContentsOfFile:path] : nil;
}

/// The string as a pixel image (1 point per pixel; display it scaled up with nearest filtering).
static UIImage *pixelText(NSString *text, BOOL gold) {
    static UIImage *white, *goldStrip;
    if (!white) { white = controlImage(@"font_white"); goldStrip = controlImage(@"font_gold"); }
    UIImage *strip = gold ? goldStrip : white;
    text = text.uppercaseString;
    if (!strip || text.length == 0) return nil;
    CGFloat w = text.length * 6 + 1, h = 9;
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = 1;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(w, h) format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextSetInterpolationQuality(ctx.CGContext, kCGInterpolationNone);
        for (NSUInteger i = 0; i < text.length; i++) {
            unichar c = [text characterAtIndex:i];
            if (c < 32 || c > 95) c = '?';
            CGImageRef glyph = CGImageCreateWithImageInRect(strip.CGImage, CGRectMake((c - 32) * 7, 0, 7, 9));
            [[UIImage imageWithCGImage:glyph] drawAtPoint:CGPointMake(i * 6, 0)];
            CGImageRelease(glyph);
        }
    }];
}

static UIImageView *pixelView(UIImage *img, CGFloat scale) {
    UIImageView *v = [[UIImageView alloc] initWithImage:img];
    v.layer.magnificationFilter = kCAFilterNearest;
    v.frame = CGRectMake(0, 0, img.size.width * scale, img.size.height * scale);
    v.userInteractionEnabled = NO;
    return v;
}

static void setPixelText(UIImageView *v, NSString *text, BOOL gold, CGFloat scale) {
    UIImage *img = pixelText(text, gold);
    v.image = img;
    CGPoint c = v.center;
    v.bounds = CGRectMake(0, 0, img.size.width * scale, img.size.height * scale);
    v.center = c;
}

/// A 9-slice pixel panel, each pixel `scale` points.
/// The 2016-style menu art (ci/menu2016.py) is drawn at 3x.
static UIImage *art3(NSString *name) {
    UIImage *img = controlImage(name);
    return img ? [UIImage imageWithCGImage:img.CGImage scale:3 orientation:UIImageOrientationUp] : nil;
}
static const CGFloat kTilt[] = {-2.5, 2, -1.5, 2.5, -2, 1.5}; // degrees: hand-placed wonkiness

static UIImage *panelImage(NSString *name, CGFloat scale) {
    UIImage *base = controlImage(name);
    UIImage *scaled = [UIImage imageWithCGImage:base.CGImage scale:1.0 / scale orientation:UIImageOrientationUp];
    CGFloat cap = 6 * scale;
    return [scaled resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap) resizingMode:UIImageResizingModeStretch];
}

/// Lets a drag that starts on a game card scroll the row instead of being held by the card.
@interface CardScroll : UIScrollView
@end
@implementation CardScroll
- (BOOL)touchesShouldCancelInContentView:(UIView *)view { return YES; }
@end

@interface MenuViewController ()
@property (nonatomic, strong) UIImageView *background, *logo, *subtitle, *countText, *wideText, *wideToggle;
@property (nonatomic, strong) UIImageView *sunky, *bubble;
@property (nonatomic, strong) CardScroll *scroll;
@property (nonatomic) NSInteger focus; // card picked with a game controller, -1 = none
@property (nonatomic, strong) NSMutableArray<UIButton *> *cards;
@end

@implementation MenuViewController

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }

- (BOOL)singleGame { return [[NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"] length] > 0; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    if ([self singleGame]) { // only the all-in-one app has a menu
        for (int i = 0; i < kSunkyGameCount; i++) {
            if ([[NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"] isEqualToString:@(kSunkyGames[i].file)]) {
                UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
                b.tag = i;
                self.cards = [NSMutableArray arrayWithObject:b];
            }
        }
        return;
    }

    // "SUNKY COLECTION!!!": a 2016 fangame / MS Paint style menu (art from ci/menu2016.py)
    self.background = [[UIImageView alloc] initWithImage:art3(@"m16_bg")];
    self.background.contentMode = UIViewContentModeScaleAspectFill;
    self.background.clipsToBounds = YES;
    [self.view addSubview:self.background];
    self.logo = [[UIImageView alloc] initWithImage:art3(@"m16_title")];
    self.subtitle = [[UIImageView alloc] initWithImage:art3(@"m16_sub")];
    self.sunky = [[UIImageView alloc] initWithImage:controlImage(@"m16_sunky")];
    self.sunky.layer.magnificationFilter = kCAFilterNearest;
    self.bubble = [[UIImageView alloc] initWithImage:art3(@"m16_bubble")];
    for (UIView *v in @[self.logo, self.subtitle, self.sunky, self.bubble]) [self.view addSubview:v];

    self.cards = [NSMutableArray array];
    self.focus = -1;
    for (int i = 0; i < kSunkyGameCount; i++) {
        const SunkyGame *g = &kSunkyGames[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        b.adjustsImageWhenHighlighted = NO;
        [b setImage:art3([@"m16_btn_" stringByAppendingString:@(g->file)]) forState:UIControlStateNormal];
        [b addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
        [b addTarget:self action:@selector(squash:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [b addTarget:self action:@selector(unsquash:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
        UIImageView *done = [[UIImageView alloc] initWithImage:art3(@"m16_done")];
        done.tag = 13;
        done.userInteractionEnabled = NO;
        [b addSubview:done];
        [self.view addSubview:b];
        [self.cards addObject:b];
    }
    [self.view bringSubviewToFront:self.bubble];
}

- (void)squash:(UIButton *)b {
    [UIView animateWithDuration:0.08 animations:^{ b.transform = CGAffineTransformScale([self tiltFor:b], 0.92, 0.92); }];
}
- (void)unsquash:(UIButton *)b {
    [UIView animateWithDuration:0.12 animations:^{ b.transform = [self tiltFor:b]; }];
}
- (CGAffineTransform)tiltFor:(UIButton *)b { return CGAffineTransformMakeRotation(kTilt[b.tag % 6] * M_PI / 180.0); }

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if ([self singleGame]) return;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGSize sz = self.view.bounds.size;
    CGFloat left = MAX(safe.left, 16) + 8, right = MAX(safe.right, 16) + 8;
    self.background.frame = self.view.bounds;
    CGFloat grass = sz.height * 0.82;  // where the grass starts in m16_bg (aspect-fill keeps the height)

    // title across the top
    CGSize ts = self.logo.image.size;
    CGFloat tw = MIN(ts.width, (sz.width - left - right) * 0.78), th = ts.height * tw / ts.width;
    self.logo.frame = CGRectMake((sz.width - tw) / 2, MAX(4, safe.top), tw, th);
    CGSize ss = self.subtitle.image.size;
    CGFloat sk = tw / ts.width;
    self.subtitle.frame = CGRectMake(CGRectGetMaxX(self.logo.frame) - ss.width * sk * 1.1, CGRectGetMaxY(self.logo.frame) - ss.height * sk * 0.35, ss.width * sk, ss.height * sk);

    // Sunky standing on the grass, bottom right, with his speech bubble
    CGFloat sunkyH = MIN(104, sz.height * 0.27);
    self.sunky.frame = CGRectMake(sz.width - right - sunkyH * 0.8, grass - sunkyH + sunkyH * 0.06, sunkyH, sunkyH);
    CGSize bs = self.bubble.image.size;
    CGFloat bk = MIN(1, (sunkyH * 1.5) / bs.width);
    self.bubble.frame = CGRectMake(sz.width - right - bs.width * bk + 6, CGRectGetMinY(self.sunky.frame) - bs.height * bk + 6, bs.width * bk, bs.height * bk);

    // 3 x 2 grid of buttons between the title and the grass, leaving room for Sunky
    CGFloat gridLeft = left, gridRight = sz.width - right - sunkyH * 0.85;
    CGFloat top = CGRectGetMaxY(self.logo.frame) + 6, bottom = grass + 8;
    CGFloat gapX = 18, gapY = 14;
    CGSize nat = [self.cards.firstObject imageForState:UIControlStateNormal].size;
    // as big as fits both across and down (and no bigger than 1.15x the drawing)
    CGFloat byWidth = (gridRight - gridLeft - 2 * gapX) / 3;
    CGFloat byHeight = (bottom - top - gapY) / 2 * nat.width / nat.height;
    CGFloat bw = MIN(nat.width * 1.15, MIN(byWidth, byHeight));
    CGFloat bh = bw * nat.height / nat.width;
    CGFloat gx = gridLeft + ((gridRight - gridLeft) - (3 * bw + 2 * gapX)) / 2;
    CGFloat gy = top + ((bottom - top) - (2 * bh + gapY)) / 2;
    for (UIButton *b in self.cards) {
        NSInteger i = b.tag;
        b.transform = CGAffineTransformIdentity;
        b.frame = CGRectMake(gx + (i % 3) * (bw + gapX), gy + (i / 3) * (bh + gapY), bw, bh);
        b.transform = [self tiltFor:b];
        UIView *done = [b viewWithTag:13];
        CGSize dsz = ((UIImageView *)done).image.size;
        CGFloat dk = bw / nat.width;
        done.frame = CGRectMake(bw - dsz.width * dk * 0.8, -dsz.height * dk * 0.45, dsz.width * dk, dsz.height * dk);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshFinished];
    [self hookControllers];
}

// ---- Game controllers: left/right (D-pad or stick) picks a game, A or Menu plays it ----

- (void)hookControllers {
    if ([self singleGame] || self.navigationController.topViewController != self) return;
    static BOOL observing;
    if (!observing) {
        observing = YES;
        [NSNotificationCenter.defaultCenter addObserverForName:GCControllerDidConnectNotification object:nil queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *n) { [self hookControllers]; }];
    }
    __weak MenuViewController *weakSelf = self;
    for (GCController *c in GCController.controllers) {
        GCExtendedGamepad *pad = c.extendedGamepad;
        if (!pad) continue;
        __block int lastDir = 0;
        GCControllerDirectionPadValueChangedHandler dir = ^(GCControllerDirectionPad *d, float x, float y) {
            int now = x > 0.5 ? 1 : x < -0.5 ? -1 : y < -0.5 ? 3 : y > 0.5 ? -3 : 0; // grid of 3 across
            if (now && now != lastDir) [weakSelf moveFocus:now];
            lastDir = now;
        };
        pad.dpad.valueChangedHandler = dir;
        pad.leftThumbstick.valueChangedHandler = dir;
        GCControllerButtonValueChangedHandler go = ^(GCControllerButtonInput *b, float v, BOOL pressed) {
            MenuViewController *me = weakSelf;
            if (!pressed || !me || me.navigationController.topViewController != me) return;
            if (me.focus < 0) { [me moveFocus:0]; return; }
            [me play:me.cards[me.focus]];
        };
        pad.buttonA.valueChangedHandler = go;
        pad.buttonMenu.valueChangedHandler = go;
        pad.buttonB.valueChangedHandler = nil;
        pad.buttonX.valueChangedHandler = nil;
        pad.buttonY.valueChangedHandler = nil;
        if (pad.buttonOptions) pad.buttonOptions.valueChangedHandler = nil;
    }
}

- (void)moveFocus:(int)step {
    if (self.navigationController.topViewController != self || !self.cards.count) return;
    NSInteger n = (NSInteger)self.cards.count;
    NSInteger next = self.focus < 0 ? 0 : self.focus + step;
    if (next >= 0 && next < n) self.focus = next;
    [self refreshFinished];
}

- (void)refreshFinished {
    if ([self singleGame]) return;
    for (UIButton *b in self.cards) {
        const SunkyGame *g = &kSunkyGames[b.tag];
        [b viewWithTag:13].hidden = !SunkyIsFinished(g);
        BOOL focused = self.focus >= 0 && b.tag == self.cards[self.focus].tag;
        [b setImage:art3([NSString stringWithFormat:@"m16_btn_%s%@", g->file, focused ? @"_focus" : @""]) forState:UIControlStateNormal];
    }
    self.bubble.image = art3(SunkyFinishedCount() == kSunkyGameCount ? @"m16_bubble_all" : @"m16_bubble");
    [self.view setNeedsLayout];
}

// Test hook for the Simulator run (ci/sim.sh): -sunkyAutoplay <game> starts that game straight away.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    static BOOL done;
    if ([self singleGame]) { // straight (back) into the game
        [self play:self.cards.firstObject];
        return;
    }
    NSString *auto_ = [NSUserDefaults.standardUserDefaults stringForKey:@"sunkyAutoplay"];
    if (done || !auto_) return;
    done = YES;
    for (UIButton *card in self.cards) {
        if ([auto_ isEqualToString:@(kSunkyGames[card.tag].file)]) [self play:card];
    }
}

- (void)play:(UIButton *)sender {
    const SunkyGame *g = &kSunkyGames[sender.tag];
    if (g->engine == 1) { // GameMaker Studio: Games/<file>/data.win, saves in Documents/<file>
        NSString *dataWin = [NSBundle.mainBundle pathForResource:@"data" ofType:@"win" inDirectory:[@"Games" stringByAppendingPathComponent:@(g->file)]];
        if (!dataWin) { SunkyLog(@"missing data.win for %s", g->file); return; }
        [self.navigationController pushViewController:[[GameViewController alloc] initWithGame:g exe:dataWin title:@(g->title)] animated:![self singleGame]];
        return;
    }
    NSString *bundled = [NSBundle.mainBundle pathForResource:@(g->file) ofType:@"exe" inDirectory:@"Games"];
    if (!bundled) {
        SunkyLog(@"missing game file %s", g->file);
        return;
    }
    // Save folder with a link to the game (the app bundle is read-only; saves go next to the game).
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *folder = [SunkyDocuments() stringByAppendingPathComponent:@(g->file)];
    [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *link = [folder stringByAppendingPathComponent:@"game.exe"];
    [fm removeItemAtPath:link error:nil]; // the bundle moves when the app is updated
    NSError *err = nil;
    if (![fm createSymbolicLinkAtPath:link withDestinationPath:bundled error:&err]) {
        SunkyLog(@"symlink failed (%@), copying instead", err);
        [fm copyItemAtPath:bundled toPath:link error:nil];
    }
    NSString *title = [NSString stringWithFormat:@"%s %s", g->title, g->subtitle];
    if (strncmp(g->subtitle, "Part", 4) != 0) title = @(g->title);
    [self.navigationController pushViewController:[[GameViewController alloc] initWithGame:g exe:link title:title] animated:![self singleGame]];
}

@end
