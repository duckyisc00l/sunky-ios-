// Pick a game. Each game gets its own save folder: Documents/<game>/ (visible in the Files app).
#import "MenuViewController.h"
#import "GameViewController.h"
#import "Sunky.h"

@interface MenuViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) NSMutableArray<UIButton *> *cards;
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
    for (int i = 0; i < kSunkyGameCount; i++) {
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
        [self.scroll addSubview:b];
        [self.cards addObject:b];
    }

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
        x += cardW + gap;
    }
    self.scroll.contentSize = CGSizeMake(x - gap + right, h);
}

// Test hook for the Simulator run (ci/sim.sh): -sunkyAutoplay <game> starts that game straight away.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    static BOOL done;
    NSString *auto_ = [NSUserDefaults.standardUserDefaults stringForKey:@"sunkyAutoplay"];
    if (done || !auto_) return;
    done = YES;
    for (int i = 0; i < kSunkyGameCount; i++) {
        if ([auto_ isEqualToString:@(kSunkyGames[i].file)]) [self play:self.cards[i]];
    }
}

- (void)play:(UIButton *)sender {
    const SunkyGame *g = &kSunkyGames[sender.tag];
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
    [self.navigationController pushViewController:[[GameViewController alloc] initWithExe:link title:title] animated:YES];
}

@end
