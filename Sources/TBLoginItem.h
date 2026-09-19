#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TBLoginItemStatus) {
    TBLoginItemUnavailable,
    TBLoginItemDisabled,
    TBLoginItemEnabled,
    TBLoginItemRequiresApproval,
    TBLoginItemNotFound
};

@interface TBLoginItem : NSObject
@property(nonatomic, readonly) TBLoginItemStatus status;
- (instancetype)initWithPreview:(BOOL)preview;
- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error;
@end
