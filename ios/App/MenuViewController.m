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
@property (nonatomic, strong) UIImageView *heading, *countText;
@property (nonatomic, strong) UIView *topBar, *topStripe, *bottomBar, *bottomStripe;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic) NSInteger selected;
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

    // Sonic 3 style save-select: blue checks, red and gold bars, a row of framed game cards.
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(48, 48)];
    UIImage *checks = [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [[UIColor colorWithRed:30/255.0 green:56/255.0 blue:170/255.0 alpha:1] setFill]; UIRectFill(CGRectMake(0, 0, 48, 48));
        [[UIColor colorWithRed:20/255.0 green:40/255.0 blue:140/255.0 alpha:1] setFill];
        UIRectFill(CGRectMake(24, 0, 24, 24)); UIRectFill(CGRectMake(0, 24, 24, 24));
    }];
    self.view.backgroundColor = [UIColor colorWithPatternImage:checks];
    UIColor *red = [UIColor colorWithRed:200/255.0 green:20/255.0 blue:30/255.0 alpha:1];
    UIColor *gold = [UIColor colorWithRed:1 green:214/255.0 blue:0 alpha:1];
    self.topBar = [UIView new]; self.topBar.backgroundColor = red;
    self.bottomBar = [UIView new]; self.bottomBar.backgroundColor = red;
    self.topStripe = [UIView new]; self.topStripe.backgroundColor = gold;
    self.bottomStripe = [UIView new]; self.bottomStripe.backgroundColor = gold;
    for (UIView *v in @[self.topBar, self.bottomBar, self.topStripe, self.bottomStripe]) [self.view addSubview:v];
    self.heading = pixelView(pixelText(@"SELECT A GAME", YES), 4);
    [self.view addSubview:self.heading];
    self.countText = pixelView(pixelText(@" ", NO), 2.2);
    [self.view addSubview:self.countText];

    self.scroll = [UIScrollView new];
    self.scroll.showsHorizontalScrollIndicator = NO;
    self.scroll.alwaysBounceHorizontal = YES;
    self.scroll.delaysContentTouches = NO;
    [self.view addSubview:self.scroll];

    self.cards = [NSMutableArray array];
    self.selected = -1;
    for (int i = 0; i < kSunkyGameCount; i++) {
        const SunkyGame *g = &kSunkyGames[i];
        UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
        card.tag = i;
        card.layer.borderColor = UIColor.blackColor.CGColor;
        card.layer.borderWidth = 4;
        [card addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
        [card addTarget:self action:@selector(pick:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        UIView *box = [UIView new];
        box.backgroundColor = UIColor.blackColor;
        box.userInteractionEnabled = NO;
        box.tag = 10;
        [card addSubview:box];
        NSString *iconPath = [NSBundle.mainBundle pathForResource:@(g->file) ofType:@"png" inDirectory:@"Games"];
        UIImageView *pic = [[UIImageView alloc] initWithImage:iconPath ? [UIImage imageWithContentsOfFile:iconPath] : nil];
        pic.contentMode = UIViewContentModeScaleAspectFill;
        pic.clipsToBounds = YES;
        pic.tag = 12;
        [box addSubview:pic];
        // the logo on the title already says SUNKY THE GAME, so names stay short and big
        NSString *name;
        if (strncmp(g->subtitle, "Part", 4) == 0) name = [@(g->subtitle) uppercaseString];
        else if (g->engine == 1) name = @"SUNKY 2";
        else name = [@(g->title) uppercaseString];
        UIImageView *t = pixelView(pixelText(name, NO), 2.4);
        t.tag = 11;
        [card addSubview:t];
        UIImageView *star = pixelView(controlImage(@"star"), 3);
        star.tag = 13;
        [card addSubview:star];
        [self.scroll addSubview:card];
        [self.cards addObject:card];
    }
}

- (void)pick:(UIButton *)card {
    self.selected = card.tag;
    UIColor *gold = [UIColor colorWithRed:1 green:214/255.0 blue:0 alpha:1];
    UIColor *white = [UIColor colorWithRed:230/255.0 green:230/255.0 blue:240/255.0 alpha:1];
    for (UIButton *c in self.cards) c.backgroundColor = c.tag == self.selected ? gold : white;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if ([self singleGame]) return;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGSize b = self.view.bounds.size;
    CGFloat side = MAX(MAX(safe.left, safe.right), 16);
    CGFloat topH = MAX(54, b.height * 0.14), botH = MAX(40, b.height * 0.10);
    self.topBar.frame = CGRectMake(0, 0, b.width, topH);
    self.topStripe.frame = CGRectMake(0, topH, b.width, 6);
    self.bottomBar.frame = CGRectMake(0, b.height - botH, b.width, botH);
    self.bottomStripe.frame = CGRectMake(0, b.height - botH - 6, b.width, 6);
    CGFloat hs = MIN(4, (topH - 14) / 9.0);
    self.heading.bounds = CGRectMake(0, 0, self.heading.image.size.width * hs, self.heading.image.size.height * hs);
    self.heading.center = CGPointMake(b.width / 2, topH / 2);
    self.countText.center = CGPointMake(b.width / 2, b.height - botH / 2);

    // cards: as tall as the space between the bars allows
    CGFloat areaTop = topH + 6, areaH = b.height - botH - 6 - areaTop;
    CGFloat ch = areaH * 0.82, cw = ch * 150.0 / 210.0, gap = 16;
    self.scroll.frame = CGRectMake(0, areaTop, b.width, areaH);
    self.scroll.contentInset = UIEdgeInsetsMake(0, side + 6, 0, side + 6);
    CGFloat y = (areaH - ch) / 2;
    for (NSUInteger i = 0; i < self.cards.count; i++) {
        UIButton *card = self.cards[i];
        card.frame = CGRectMake(i * (cw + gap), y, cw, ch);
        UIView *box = [card viewWithTag:10];
        box.frame = CGRectMake(10, 10, cw - 20, cw - 20);
        [box viewWithTag:12].frame = box.bounds;
        UIImageView *t = (UIImageView *)[card viewWithTag:11];
        CGFloat sc = MIN(2.4, (cw - 16) / t.image.size.width);
        t.bounds = CGRectMake(0, 0, t.image.size.width * sc, t.image.size.height * sc);
        t.center = CGPointMake(cw / 2, (CGRectGetMaxY(box.frame) + ch) / 2);
        UIView *star = [card viewWithTag:13];
        star.center = CGPointMake(cw - star.bounds.size.width / 2 + 8, star.bounds.size.height / 2 - 10);
    }
    self.scroll.contentSize = CGSizeMake(self.cards.count * (cw + gap) - gap, areaH);
    // more room than cards: centre them
    CGFloat spare = b.width - self.scroll.contentSize.width - 2 * (side + 6);
    if (spare > 0) self.scroll.contentInset = UIEdgeInsetsMake(0, side + 6 + spare / 2, 0, side + 6 + spare / 2);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshFinished];
}

- (void)refreshFinished {
    if ([self singleGame]) return;
    NSInteger firstOpen = -1;
    for (UIButton *card in self.cards) {
        BOOL fin = SunkyIsFinished(&kSunkyGames[card.tag]);
        [card viewWithTag:13].hidden = !fin;
        if (!fin && firstOpen < 0) firstOpen = card.tag;
    }
    if (self.selected < 0 && self.cards.count) [self pick:self.cards[MAX(0, firstOpen)]];
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
