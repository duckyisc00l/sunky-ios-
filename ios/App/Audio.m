// RemoteIO output: each buffer is filled by the runner's mixer through udon_ios_render.
#import "Audio.h"
#import "Sunky.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

static AudioUnit gUnit;
static float *gScratch;
static UInt32 gScratchFrames;

static OSStatus render(void *ref, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *ts,
                       UInt32 bus, UInt32 frames, AudioBufferList *io) {
    float *out = (float *)io->mBuffers[0].mData;
    if (io->mNumberBuffers == 1) {
        udon_ios_render(out, frames); // interleaved stereo
    } else {
        // non-interleaved fallback
        if (frames > gScratchFrames) { for (UInt32 b = 0; b < io->mNumberBuffers; b++) memset(io->mBuffers[b].mData, 0, io->mBuffers[b].mDataByteSize); return noErr; }
        udon_ios_render(gScratch, frames);
        float *l = (float *)io->mBuffers[0].mData, *r = (float *)io->mBuffers[1].mData;
        for (UInt32 i = 0; i < frames; i++) { l[i] = gScratch[i * 2]; r[i] = gScratch[i * 2 + 1]; }
    }
    return noErr;
}

@implementation SunkyAudio
+ (void)start {
    AVAudioSession *session = AVAudioSession.sharedInstance;
    [session setCategory:AVAudioSessionCategoryAmbient error:nil]; // respects the silent switch, mixes with music
    [session setPreferredSampleRate:48000 error:nil];
    [session setPreferredIOBufferDuration:0.010 error:nil];
    [session setActive:YES error:nil];
    double rate = session.sampleRate > 0 ? session.sampleRate : 48000;
    udon_ios_set_sample_rate((uint32_t)rate);

    gScratchFrames = 8192;
    gScratch = calloc(gScratchFrames * 2, sizeof(float));

    AudioComponentDescription desc = { kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0, 0 };
    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp || AudioComponentInstanceNew(comp, &gUnit) != noErr) { SunkyLog(@"audio: no RemoteIO unit"); return; }
    AudioStreamBasicDescription fmt = {0};
    fmt.mSampleRate = rate;
    fmt.mFormatID = kAudioFormatLinearPCM;
    fmt.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    fmt.mChannelsPerFrame = 2;
    fmt.mBitsPerChannel = 32;
    fmt.mBytesPerFrame = 8;
    fmt.mFramesPerPacket = 1;
    fmt.mBytesPerPacket = 8;
    AudioUnitSetProperty(gUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fmt, sizeof fmt);
    UInt32 maxFrames = 4096;
    AudioUnitSetProperty(gUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, sizeof maxFrames);
    AURenderCallbackStruct cb = { render, NULL };
    AudioUnitSetProperty(gUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &cb, sizeof cb);
    OSStatus err = AudioUnitInitialize(gUnit);
    if (err == noErr) err = AudioOutputUnitStart(gUnit);
    SunkyLog(@"audio: %.0f Hz, start status %d", rate, (int)err);

    [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *n) {
        if ([n.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue] == AVAudioSessionInterruptionTypeEnded) [SunkyAudio resume];
    }];
}
+ (void)pause {
    if (gUnit) AudioOutputUnitStop(gUnit);
}
+ (void)resume {
    if (!gUnit) return;
    [AVAudioSession.sharedInstance setActive:YES error:nil];
    AudioOutputUnitStart(gUnit);
}
@end
