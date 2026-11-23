#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "Sunky.h"
#include <signal.h>
#include <execinfo.h>
#include <unistd.h>

static int gLogFd = -1;

static void crashHandler(int sig) {
    if (gLogFd >= 0) {
        char msg[64];
        int n = snprintf(msg, sizeof msg, "\n*** crashed with signal %d\n", sig);
        write(gLogFd, msg, n);
        void *frames[64];
        int count = backtrace(frames, 64);
        backtrace_symbols_fd(frames, count, gLogFd);
    }
    signal(sig, SIG_DFL);
    raise(sig);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // Everything the runner prints goes to Documents/log.txt (the previous run's is kept too).
        NSString *docs = SunkyDocuments();
        NSString *log = [docs stringByAppendingPathComponent:@"log.txt"];
        NSString *prev = [docs stringByAppendingPathComponent:@"log-previous.txt"];
        [NSFileManager.defaultManager removeItemAtPath:prev error:nil];
        [NSFileManager.defaultManager moveItemAtPath:log toPath:prev error:nil];
        freopen(log.fileSystemRepresentation, "w", stderr);
        dup2(fileno(stderr), fileno(stdout));
        setvbuf(stderr, NULL, _IONBF, 0);
        setvbuf(stdout, NULL, _IOLBF, 0);
        gLogFd = fileno(stderr);
        int sigs[] = { SIGSEGV, SIGBUS, SIGILL, SIGABRT, SIGFPE, SIGTRAP };
        for (int i = 0; i < 6; i++) signal(sigs[i], crashHandler);
        NSSetUncaughtExceptionHandler(^(NSException *e) {
            SunkyLog(@"uncaught exception: %@ %@\n%@", e.name, e.reason, e.callStackSymbols);
        });
        NSDictionary *info = NSBundle.mainBundle.infoDictionary;
        SunkyLog(@"Sunky %@ (build %@), iOS %@", info[@"CFBundleShortVersionString"], info[@"CFBundleVersion"],
                 UIDevice.currentDevice.systemVersion);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
