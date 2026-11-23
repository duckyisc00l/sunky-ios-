#import "Sunky.h"

const SunkyGame kSunkyGames[] = {
    { "p1",   "Sunky the Game", "Part 1",                  { 2, -1 } },        // room "End"
    { "p2",   "Sunky the Game", "Part 2",                  { 2, -1 } },        // room "End"
    { "p3",   "Sunky the Game", "Part 3",                  { 37, 24, -1 } },   // "Ending", "Credits"
    { "mpeg", "Sunky.MPEG",     "The original sillypasta", { 44, -1 } },       // "Riddle" (last room)
    { "tiff", "Silly.TIFF",     "Sunky.MPEG's sequel",     { 64, 71, -1 } },   // "Credits", "End"
    { "g2",   "Sunky the Game 2", "April Fools 2016",      { 18, -1 }, 1 },    // the Credits room
};
const int kSunkyGameCount = sizeof(kSunkyGames) / sizeof(kSunkyGames[0]);

NSString *SunkyDocuments(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

void SunkyLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fprintf(stderr, "[app] %s\n", s.UTF8String);
    fflush(stderr);
}

static NSString *finishedKey(const SunkyGame *g) { return [NSString stringWithFormat:@"finished.%s", g->file]; }
BOOL SunkyIsFinished(const SunkyGame *g) { return [NSUserDefaults.standardUserDefaults boolForKey:finishedKey(g)]; }
void SunkySetFinished(const SunkyGame *g) { [NSUserDefaults.standardUserDefaults setBool:YES forKey:finishedKey(g)]; }
int SunkyFinishedCount(void) {
    int n = 0;
    for (int i = 0; i < kSunkyGameCount; i++) n += SunkyIsFinished(&kSunkyGames[i]);
    return n;
}
BOOL SunkyWidescreen(void) { return [NSUserDefaults.standardUserDefaults boolForKey:@"widescreen"]; }
void SunkySetWidescreen(BOOL on) { [NSUserDefaults.standardUserDefaults setBool:on forKey:@"widescreen"]; }
