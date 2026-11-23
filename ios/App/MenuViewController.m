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

@interface MenuViewController ()
@property (nonatomic, strong) UIImageView *background, *emblem, *arrow, *countText;
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

    // Sunky the Game's title screen: its sky, clouds, mountains and water, the winged emblem with
    // thumbs-up Sunky, and the games listed in the game's gold lettering.
    self.background = [[UIImageView alloc] initWithImage:controlImage(@"menu_title_bg")];
    self.background.contentMode = UIViewContentModeScaleAspectFill;
    self.background.clipsToBounds = YES;
    [self.view addSubview:self.background];
    self.emblem = [[UIImageView alloc] initWithImage:controlImage(@"menu_emblem")];
    self.emblem.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.emblem];

    self.cards = [NSMutableArray array];
    for (int i = 0; i < kSunkyGameCount; i++) {
        const SunkyGame *g = &kSunkyGames[i];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.tag = i;
        [row addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
        [row addTarget:self action:@selector(pointAt:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        // the emblem already says SUNKY THE GAME, so the list stays short and big
        NSString *name;
        if (strncmp(g->subtitle, "Part", 4) == 0) name = [@(g->subtitle) uppercaseString];
        else if (g->engine == 1) name = @"SUNKY 2";
        else name = [@(g->title) uppercaseString];
        UIImageView *t = pixelView(pixelText(name, YES), 3);
        t.tag = 11;
        [row addSubview:t];
        UIImageView *star = pixelView(controlImage(@"star"), 2.4);
        star.tag = 13;
        [row addSubview:star];
        [self.view addSubview:row];
        [self.cards addObject:row];
    }
    self.arrow = pixelView(pixelText(@">", YES), 3);
    [self.view addSubview:self.arrow];
    self.countText = pixelView(pixelText(@" ", NO), 2.2);
    [self.view addSubview:self.countText];
    // the arrow blinks, like PRESS START does
    [UIView animateWithDuration:0.45 delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self.arrow.alpha = 0.15; } completion:nil];
}

- (void)pointAt:(UIButton *)row {
    self.arrow.center = CGPointMake(CGRectGetMinX(row.frame) - 18, row.center.y);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if ([self singleGame]) return;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGSize b = self.view.bounds.size;
    CGFloat left = MAX(safe.left, 16), right = MAX(safe.right, 16);
    self.background.frame = self.view.bounds;

    // emblem on the left, as big as the height allows
    CGFloat eh = b.height * 0.94;
    CGFloat ew = MIN(eh * 590.0 / 455.0, b.width * 0.48);
    eh = ew * 455.0 / 590.0;
    self.emblem.frame = CGRectMake(left - 6, (b.height - eh) / 2, ew, eh);

    // the list on the right, centred in the space left
    CGFloat listX = CGRectGetMaxX(self.emblem.frame) + 30;
    CGFloat listW = b.width - right - listX;
    CGFloat rowH = MIN(46, (b.height - 70) / MAX(1, self.cards.count));
    CGFloat top = (b.height - rowH * self.cards.count - 30) / 2;
    for (NSUInteger i = 0; i < self.cards.count; i++) {
        UIButton *row = self.cards[i];
        UIImageView *t = (UIImageView *)[row viewWithTag:11], *star = (UIImageView *)[row viewWithTag:13];
        CGFloat sc = MIN(3, (listW - 34) / t.image.size.width);
        t.bounds = CGRectMake(0, 0, t.image.size.width * sc, t.image.size.height * sc);
        row.frame = CGRectMake(listX, top + i * rowH, listW, rowH);
        t.frame = CGRectMake(0, (rowH - t.bounds.size.height) / 2, t.bounds.size.width, t.bounds.size.height);
        star.center = CGPointMake(CGRectGetMaxX(t.frame) + 8 + star.bounds.size.width / 2, rowH / 2);
    }
    if (self.arrow.center.x < 1 && self.cards.count) [self pointAt:self.cards.firstObject];
    else if (self.cards.count) {
        // keep the arrow on its row after a layout change
        UIButton *nearest = self.cards.firstObject;
        for (UIButton *r in self.cards) if (fabs(r.center.y - self.arrow.center.y) < fabs(nearest.center.y - self.arrow.center.y)) nearest = r;
        [self pointAt:nearest];
    }
    CGRect f = self.countText.frame;
    f.origin = CGPointMake(listX, top + rowH * self.cards.count + 10);
    self.countText.frame = f;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshFinished];
}

- (void)refreshFinished {
    if ([self singleGame]) return;
    for (UIButton *row in self.cards) {
        [row viewWithTag:13].hidden = !SunkyIsFinished(&kSunkyGames[row.tag]);
    }
    int n = SunkyFinishedCount();
    NSString *t = n == kSunkyGameCount ? [NSString stringWithFormat:@"ALL %d FINISHED!", n]
                                       : [NSString stringWithFormat:@"%d OF %d FINISHED", n, kSunkyGameCount];
    setPixelText(self.countText, t, NO, 2.2);
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
