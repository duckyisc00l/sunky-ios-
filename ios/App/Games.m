#import "Sunky.h"

const SunkyGame kSunkyGames[] = {
    { "p1",   "Sunky the Game",      "Part 1" },
    { "p2",   "Sunky the Game",      "Part 2" },
    { "p3",   "Sunky the Game",      "Part 3" },
    { "mpeg", "Sunky.MPEG",          "The original sillypasta" },
    { "tiff", "Silly.TIFF",          "Sunky.MPEG's sequel" },
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
