#import <AVFoundation/AVFoundation.h>

#import "SpeechTextPlugin.h"
#import "AudioController.h"
#import "SpeechRecognitionService.h"
#import "google/cloud/speech/v1p1beta1/CloudSpeech.pbrpc.h"


#define SAMPLE_RATE 16000.0f

@interface SpeechTextPlugin () <AudioControllerDelegate>
@property (nonatomic, strong) NSMutableData *audioData;
@end

@implementation SpeechTextPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"speech_text"
            binaryMessenger:[registrar messenger]];
  SpeechTextPlugin* instance = [[SpeechTextPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];

  // user code below
  [AudioController sharedInstance].delegate = instance;
}

// flutter methods
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS hello " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  }
  else if ([@"apiKey" isEqualToString:call.method]) {
    result(nil);
  }
  else if ([@"languageCode" isEqualToString:call.method]) {
    result(nil);
  }
  else if ([@"speechContextsArray" isEqualToString:call.method]) {
    result(@"called speech contexts array ");
  }
  else if ([@"model" isEqualToString:call.method]) {
    result(nil);
  }
    else if ([@"start" isEqualToString:call.method]) {
        [self recordAudio];
      result(nil);
    }

    else if ([@"stop" isEqualToString:call.method]) {
        [self stopAudio];
      result(nil);
    }
  else {
    result(FlutterMethodNotImplemented);
  }
}

// Audio methods

- (void)recordAudio {
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];

  _audioData = [[NSMutableData alloc] init];
  [[AudioController sharedInstance] prepareWithSampleRate:SAMPLE_RATE];
  [[SpeechRecognitionService sharedInstance] setSampleRate:SAMPLE_RATE];
  [[AudioController sharedInstance] start];
}

- (void)stopAudio {
  [[AudioController sharedInstance] stop];
  [[SpeechRecognitionService sharedInstance] stopStreaming];
}

- (void)processSampleData:(NSData *)data {
    [self.audioData appendData:data];
    NSInteger frameCount = [data length] / 2;
    int16_t *samples = (int16_t *) [data bytes];
    int64_t sum = 0;
    for (int i = 0; i < frameCount; i++) {
      sum += abs(samples[i]);
    }
    NSLog(@"audio %d %d", (int) frameCount, (int) (sum * 1.0 / frameCount));

    // We recommend sending samples in 100ms chunks
    int chunk_size = 0.1 /* seconds/chunk */ * SAMPLE_RATE * 2 /* bytes/sample */ ; /* bytes/chunk */

    if ([self.audioData length] > chunk_size) {
      NSLog(@"SENDING");
      [[SpeechRecognitionService sharedInstance] streamAudioData:self.audioData
                                                  withCompletion:^(StreamingRecognizeResponse *response, NSError *error) {
                                                    if (error) {
                                                      NSLog(@"ERROR: %@", error);
                                                      [self stopAudio];
                                                    } else if (response) {
                                                      BOOL finished = NO;
                                                      NSLog(@"RESPONSE: %@", response);
                                                      for (StreamingRecognitionResult *result in response.resultsArray) {
                                                        if (result.isFinal) {
                                                          finished = YES;
                                                        }
                                                      }
                                                        NSLog(@"RESPONSE: %@", response);
                                                      if (finished) {
                                                        [self stopAudio];
                                                      }
                                                    }
                                                  }
       ];
      self.audioData = [[NSMutableData alloc] init];
    }
}

@end
