#import "TBWakeRequest.h"

@interface NSObject (TBWakeClient)
- (BOOL)turnOnWithPeriod:(float)period;
@end

BOOL TBSupportsImmediateWake(id client) {
    @try {
        NSMethodSignature *signature = [client methodSignatureForSelector:@selector(turnOnWithPeriod:)];
        return signature && signature.numberOfArguments == 3 &&
            strcmp(signature.methodReturnType, @encode(BOOL)) == 0 &&
            strcmp([signature getArgumentTypeAtIndex:2], @encode(float)) == 0;
    } @catch (NSException *exception) { (void)exception; return NO; }
}

BOOL TBRequestWake(id client) {
    if (!TBSupportsImmediateWake(client)) return NO;
    // The default turnOn uses a 0.5-second fade on the validated system. Skip
    // that ramp through low brightness, just as immediate Off skips dimming.
    @try { return [client turnOnWithPeriod:0.0f]; }
    @catch (NSException *exception) { (void)exception; return NO; }
}
