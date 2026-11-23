// Pick a game. Each game gets its own save folder: Documents/<game>/ (visible in the Files app).
#import "MenuViewController.h"
#import "GameViewController.h"
#import "Sunky.h"

@interface MenuViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) NSMutableArray<UIButton *> *cards;
@property (nonatomic, strong) UISwitch *wideSwitch;
@property (nonatomic, strong) UILabel *wideLabel, *countLabel;
@end

@implementation MenuViewController

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.12 blue:0.45 alpha:1];

    UILabel *title = [UILabel new];
    title.text = @"SUNKY";
    title.font = [UIFont systemFontOfSize:44 weight:UIFontWeightBlack];
    title.textColor = UIColor.whiteColor;
    title.tag = 1;
    [self.view addSubview:title];
    UILabel *sub = [UILabel new];
    sub.text = @"Pick a game";
    sub.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.7];
    sub.tag = 2;
    [self.view addSubview:sub];

    self.scroll = [UIScrollView new];
    self.scroll.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:self.scroll];
    self.cards = [NSMutableArray array];
    // Single-game apps (SunkyOnly in Info.plist) show just their own game and start it straight away.
    NSString *only = [NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"];
    if (only.length) {
        title.text = @"SUNKY";
        sub.text = @"Tap to play";
    }
    for (int i = 0; i < kSunkyGameCount; i++) {
        if (only.length && ![only isEqualToString:@(kSunkyGames[i].file)]) continue;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
        b.layer.cornerRadius = 18;
        b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
        b.layer.borderWidth = 2;
        b.clipsToBounds = YES;
        [b addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];

        NSString *iconPath = [NSBundle.mainBundle pathForResource:@(kSunkyGames[i].file) ofType:@"png" inDirectory:@"Games"];
        UIImageView *icon = [[UIImageView alloc] initWithImage:iconPath ? [UIImage imageWithContentsOfFile:iconPath] : nil];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.layer.magnificationFilter = kCAFilterNearest;
        icon.tag = 10;
        icon.userInteractionEnabled = NO;
        [b addSubview:icon];
        UILabel *name = [UILabel new];
        name.text = @(kSunkyGames[i].title);
        name.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        name.textColor = UIColor.whiteColor;
        name.textAlignment = NSTextAlignmentCenter;
        name.adjustsFontSizeToFitWidth = YES;
        name.tag = 11;
        [b addSubview:name];
        UILabel *detail = [UILabel new];
        detail.text = @(kSunkyGames[i].subtitle);
        detail.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        detail.textColor = [UIColor colorWithWhite:1 alpha:0.75];
        detail.textAlignment = NSTextAlignmentCenter;
        detail.adjustsFontSizeToFitWidth = YES;
        detail.tag = 12;
        [b addSubview:detail];
        UILabel *badge = [UILabel new];
        badge.text = @" ✓ FINISHED ";
        badge.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = [UIColor colorWithRed:0.1 green:0.65 blue:0.25 alpha:1];
        badge.layer.cornerRadius = 8;
        badge.clipsToBounds = YES;
        badge.tag = 13;
        [badge sizeToFit];
        [b addSubview:badge];
        [self.scroll addSubview:b];
        [self.cards addObject:b];
    }

    self.countLabel = [UILabel new];
    self.countLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    self.countLabel.textColor = [UIColor colorWithRed:0.55 green:1 blue:0.6 alpha:1];
    [self.view addSubview:self.countLabel];

    self.wideLabel = [UILabel new];
    self.wideLabel.text = @"Widescreen";
    self.wideLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.wideLabel.textColor = UIColor.whiteColor;
    [self.wideLabel sizeToFit];
    [self.view addSubview:self.wideLabel];
    self.wideSwitch = [UISwitch new];
    self.wideSwitch.on = SunkyWidescreen();
    [self.wideSwitch addTarget:self action:@selector(wideChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.wideSwitch];

    UILabel *credit = [UILabel new];
    credit.text = @"Games by LooneyDude · runs on OpenGMK";
    credit.font = [UIFont systemFontOfSize:12];
    credit.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    credit.tag = 3;
    [self.view addSubview:credit];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGSize b = self.view.bounds.size;
    CGFloat left = MAX(safe.left, 20), right = MAX(safe.right, 20);
    UILabel *title = [self.view viewWithTag:1], *sub = [self.view viewWithTag:2], *credit = [self.view viewWithTag:3];
    [title sizeToFit]; [sub sizeToFit]; [credit sizeToFit];
    CGFloat top = MAX(safe.top, 16);
    title.frame = CGRectMake(left, top, title.bounds.size.width, title.bounds.size.height);
    sub.frame = CGRectMake(left + 2, CGRectGetMaxY(title.frame) - 2, sub.bounds.size.width, sub.bounds.size.height);
    credit.frame = CGRectMake(left, b.height - MAX(safe.bottom, 10) - credit.bounds.size.height, credit.bounds.size.width, credit.bounds.size.height);

    [self.countLabel sizeToFit];
    self.countLabel.frame = CGRectMake(CGRectGetMaxX(sub.frame) + 14, sub.frame.origin.y, self.countLabel.bounds.size.width, sub.bounds.size.height);
    CGSize sw = self.wideSwitch.bounds.size;
    self.wideSwitch.frame = CGRectMake(b.width - right - sw.width, top + 6, sw.width, sw.height);
    self.wideLabel.center = CGPointMake(CGRectGetMinX(self.wideSwitch.frame) - 10 - self.wideLabel.bounds.size.width / 2, self.wideSwitch.center.y);

    CGFloat y = CGRectGetMaxY(sub.frame) + 14;
    CGFloat h = CGRectGetMinY(credit.frame) - 10 - y;
    self.scroll.frame = CGRectMake(0, y, b.width, h);
    CGFloat cardW = MIN(190, h * 0.82), gap = 16, x = left;
    for (UIButton *card in self.cards) {
        card.frame = CGRectMake(x, 0, cardW, h);
        UIView *icon = [card viewWithTag:10], *name = [card viewWithTag:11], *detail = [card viewWithTag:12];
        icon.frame = CGRectMake(16, 14, cardW - 32, h - 90);
        name.frame = CGRectMake(8, h - 70, cardW - 16, 26);
        detail.frame = CGRectMake(8, h - 42, cardW - 16, 22);
        UIView *badge = [card viewWithTag:13];
        badge.frame = CGRectMake(cardW - badge.bounds.size.width - 8, 8, badge.bounds.size.width, 24);
        x += cardW + gap;
    }
    self.scroll.contentSize = CGSizeMake(x - gap + right, h);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshFinished];
}

- (void)refreshFinished {
    for (UIButton *card in self.cards) {
        BOOL done = SunkyIsFinished(&kSunkyGames[card.tag]);
        [card viewWithTag:13].hidden = !done;
        card.layer.borderColor = (done ? [UIColor colorWithRed:0.3 green:0.9 blue:0.4 alpha:0.9] : [UIColor colorWithWhite:1 alpha:0.3]).CGColor;
    }
    if ([[NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"] length]) { self.countLabel.text = @""; return; }
    int n = SunkyFinishedCount();
    self.countLabel.text = n == kSunkyGameCount ? [NSString stringWithFormat:@"🏆 All %d finished!", n]
                                                : [NSString stringWithFormat:@"%d of %d finished", n, kSunkyGameCount];
    [self.view setNeedsLayout];
}

- (void)wideChanged:(UISwitch *)s {
    SunkySetWidescreen(s.on);
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
