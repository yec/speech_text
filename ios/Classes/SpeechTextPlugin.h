#import <Flutter/Flutter.h>

@interface SpeechTextPlugin : NSObject<FlutterPlugin>
- (void)recordAudio;
- (void)stopAudio;
@end
