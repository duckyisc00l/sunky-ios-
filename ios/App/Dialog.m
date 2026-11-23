// GameMaker's pop-ups (show_message, show_question, get_string) as iPhone alerts.
// Called by the runner (engine/ogmk/gm8emulator/src/dialog.rs) on its own thread, which waits here
// until the player answers, just like the game would on Windows.
#import <UIKit/UIKit.h>
#import "Sunky.h"

static UIViewController *topController(void) {
    UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:[UINavigationController class]]) vc = ((UINavigationController *)vc).topViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

int32_t sunky_dialog(int32_t kind, const char *text, const char *def, char *out, size_t outLen) {
    if ([NSThread isMainThread]) return 1; // never block the UI thread
    NSString *message = @(text ?: "");
    NSString *defaultText = @(def ?: "");
    __block int32_t result = 1;
    __block NSString *answer = defaultText;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:nil message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
        if (kind == 2) {
            [a addTextFieldWithConfigurationHandler:^(UITextField *f) {
                f.text = defaultText;
                f.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
                f.autocorrectionType = UITextAutocorrectionTypeNo;
                f.spellCheckingType = UITextSpellCheckingTypeNo;
                f.returnKeyType = UIReturnKeyDone;
            }];
        }
        if (kind == 1) {
            [a addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x) {
                result = 0; dispatch_semaphore_signal(done);
            }]];
            [a addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
                result = 1; dispatch_semaphore_signal(done);
            }]];
        } else {
            if (kind == 2) {
                [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x) {
                    result = 0; dispatch_semaphore_signal(done);
                }]];
            }
            __weak UIAlertController *weakA = a;
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
                if (kind == 2) answer = weakA.textFields.firstObject.text ?: @"";
                result = 1; dispatch_semaphore_signal(done);
            }]];
        }
        [topController() presentViewController:a animated:YES completion:nil];
    });
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    // The tap that opened this is over: let go of the mouse so the game doesn't ask again.
    ramen_ios_mouse_button(0, false);
    if (kind == 2 && out && outLen > 0) {
        strlcpy(out, answer.UTF8String ?: "", outLen);
    }
    return result;
}
