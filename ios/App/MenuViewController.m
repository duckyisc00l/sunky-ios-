// Pick a game, in the same pixel-art style as the controls (art drawn by ci/menu_art.py).
// Each game gets its own save folder: Documents/<game>/ (visible in the Files app).
#import "MenuViewController.h"
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
static UIImage *panelImage(NSString *name, CGFloat scale) {
    UIImage *base = controlImage(name);
    UIImage *scaled = [UIImage imageWithCGImage:base.CGImage scale:1.0 / scale orientation:UIImageOrientationUp];
    CGFloat cap = 6 * scale;
    return [scaled resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap) resizingMode:UIImageResizingModeStretch];
}

@interface MenuViewController ()
@property (nonatomic, strong) UIImageView *background, *logo, *subtitle, *countText, *wideText, *wideToggle;
@property (nonatomic, strong) UIScrollView *scroll;
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

    self.background = [[UIImageView alloc] initWithImage:controlImage(@"menu_bg")];
    self.background.contentMode = UIViewContentModeScaleAspectFill;
    self.background.layer.magnificationFilter = kCAFilterNearest;
    self.background.clipsToBounds = YES;
    [self.view addSubview:self.background];

    self.logo = pixelView(pixelText(@"SUNKY", YES), 9);
    self.subtitle = pixelView(pixelText([self singleGame] ? @"TAP TO PLAY" : @"PICK A GAME", NO), 3);
    self.countText = pixelView(pixelText(@" ", YES), 3);
    self.wideText = pixelView(pixelText(@"WIDESCREEN", NO), 2.5);
    self.wideToggle = pixelView(controlImage(SunkyWidescreen() ? @"toggle_on" : @"toggle_off"), 3.5);
    for (UIView *v in @[self.logo, self.subtitle, self.countText]) [self.view addSubview:v];

    self.scroll = [UIScrollView new];
    self.scroll.showsHorizontalScrollIndicator = NO;
    self.scroll.clipsToBounds = NO;
    [self.view addSubview:self.scroll];
    self.cards = [NSMutableArray array];

    NSString *only = [NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"];
    for (int i = 0; i < kSunkyGameCount; i++) {
        if (only.length && ![only isEqualToString:@(kSunkyGames[i].file)]) continue;
        const SunkyGame *g = &kSunkyGames[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        [b setBackgroundImage:panelImage(@"panel", 3) forState:UIControlStateNormal];
        [b setBackgroundImage:panelImage(@"panel_on", 3) forState:UIControlStateHighlighted];
        b.adjustsImageWhenHighlighted = NO;
        [b addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];

        NSString *iconPath = [NSBundle.mainBundle pathForResource:@(g->file) ofType:@"png" inDirectory:@"Games"];
        UIImageView *icon = [[UIImageView alloc] initWithImage:iconPath ? [UIImage imageWithContentsOfFile:iconPath] : nil];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.layer.magnificationFilter = kCAFilterNearest;
        icon.tag = 10;
        icon.userInteractionEnabled = NO;
        [b addSubview:icon];

        // "SUNKY THE GAME" + "PART 1", or the game's name + a short line
        BOOL part = strncmp(g->subtitle, "Part", 4) == 0;
        NSString *line1 = part ? @"SUNKY THE GAME" : @(g->title);
        NSString *line2 = part ? @(g->subtitle) : @(g->subtitle);
        UIImageView *t1 = pixelView(pixelText(line1, NO), 2), *t2 = pixelView(pixelText(line2, YES), 2);
        t1.tag = 11; t2.tag = 12;
        [b addSubview:t1];
        [b addSubview:t2];

        UIImageView *star = pixelView(controlImage(@"star"), 3);
        star.tag = 13;
        [b addSubview:star];
        [self.scroll addSubview:b];
        [self.cards addObject:b];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGSize b = self.view.bounds.size;
    CGFloat left = MAX(safe.left, 24), right = MAX(safe.right, 24), top = MAX(safe.top, 14);
    self.background.frame = self.view.bounds;

    CGRect f = self.logo.frame;
    f.origin = CGPointMake(left, top);
    self.logo.frame = f;
    f = self.subtitle.frame;
    f.origin = CGPointMake(left + 4, CGRectGetMaxY(self.logo.frame) + 6);
    self.subtitle.frame = f;
    f = self.countText.frame;
    f.origin = CGPointMake(CGRectGetMaxX(self.subtitle.frame) + 18, self.subtitle.frame.origin.y);
    self.countText.frame = f;

    CGFloat y = CGRectGetMaxY(self.subtitle.frame) + 16;
    CGFloat h = b.height - y - MAX(safe.bottom, 14);
    self.scroll.frame = CGRectMake(0, y, b.width, h);
    CGFloat cardW = MIN(200, h * 0.85), gap = 18, x = left;
    if ([self singleGame]) x = (b.width - cardW) / 2;
    for (UIButton *card in self.cards) {
        card.frame = CGRectMake(x, 0, cardW, h);
        UIView *icon = [card viewWithTag:10], *t1 = [card viewWithTag:11], *t2 = [card viewWithTag:12], *star = [card viewWithTag:13];
        icon.frame = CGRectMake(20, 20, cardW - 40, h - 86);
        // shrink the title to fit the card if needed
        for (UIImageView *t in @[(UIImageView *)t1, (UIImageView *)t2]) {
            CGFloat s = MIN(2, (cardW - 24) / t.image.size.width);
            t.bounds = CGRectMake(0, 0, t.image.size.width * s, t.image.size.height * s);
        }
        t1.center = CGPointMake(cardW / 2, h - 52);
        t2.center = CGPointMake(cardW / 2, h - 30);
        star.center = CGPointMake(cardW - 22, 22);
        x += cardW + gap;
    }
    self.scroll.contentSize = CGSizeMake(MAX(x - gap + right, b.width), h);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshFinished];
}

- (void)refreshFinished {
    for (UIButton *card in self.cards) {
        BOOL done = SunkyIsFinished(&kSunkyGames[card.tag]);
        [card viewWithTag:13].hidden = !done;
        [card setBackgroundImage:panelImage(done ? @"panel_done" : @"panel", 3) forState:UIControlStateNormal];
    }
    if ([self singleGame]) {
        self.countText.hidden = YES;
    } else {
        int n = SunkyFinishedCount();
        NSString *t = n == kSunkyGameCount ? [NSString stringWithFormat:@"ALL %d FINISHED!", n]
                                           : [NSString stringWithFormat:@"%d OF %d FINISHED", n, kSunkyGameCount];
        setPixelText(self.countText, t, YES, 3);
    }
    [self.view setNeedsLayout];
}

- (void)toggleWide {
    SunkySetWidescreen(!SunkyWidescreen());
    self.wideToggle.image = controlImage(SunkyWidescreen() ? @"toggle_on" : @"toggle_off");
}

// Test hook for the Simulator run (ci/sim.sh): -sunkyAutoplay <game> starts that game straight away.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    static BOOL done;
    NSString *auto_ = [NSUserDefaults.standardUserDefaults stringForKey:@"sunkyAutoplay"];
    NSString *only = [NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"];
    if (only.length) auto_ = only;
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
        [self.navigationController pushViewController:[[GameViewController alloc] initWithGame:g exe:dataWin title:@(g->title)] animated:YES];
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
    [self.navigationController pushViewController:[[GameViewController alloc] initWithGame:g exe:link title:title] animated:YES];
}

@end
