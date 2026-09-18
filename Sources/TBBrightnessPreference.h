#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSInteger TBSnapBrightnessPercent(double value);
FOUNDATION_EXPORT double TBTargetNits(NSInteger percent, double hardwareMinimum, double hardwareMaximum);

@protocol TBPreferenceStore <NSObject>
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
@end

@interface TBBrightnessPreference : NSObject
@property(nonatomic, readonly) NSInteger percent;
- (instancetype)initWithStore:(id<TBPreferenceStore>)store; // nil gives an isolated, in-memory preview.
- (void)setSelectedPercent:(double)value;
@end
