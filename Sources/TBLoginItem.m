#import "TBLoginItem.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation TBLoginItem {
    BOOL _preview;
    BOOL _previewEnabled;
}

- (instancetype)initWithPreview:(BOOL)preview {
    if (!(self = [super init])) return nil;
    _preview = preview;
    return self;
}

- (TBLoginItemStatus)status {
    if (_preview) return _previewEnabled ? TBLoginItemEnabled : TBLoginItemDisabled;
    if (@available(macOS 13.0, *)) {
        switch (SMAppService.mainAppService.status) {
            case SMAppServiceStatusNotRegistered: return TBLoginItemDisabled;
            case SMAppServiceStatusEnabled: return TBLoginItemEnabled;
            case SMAppServiceStatusRequiresApproval: return TBLoginItemRequiresApproval;
            case SMAppServiceStatusNotFound: return TBLoginItemNotFound;
        }
    }
    return TBLoginItemUnavailable;
}

- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error {
    if (error) *error = nil;
    if (_preview) {
        _previewEnabled = enabled;
        return YES;
    }
    if (@available(macOS 13.0, *)) {
        if ((enabled && self.status == TBLoginItemEnabled) || (!enabled && self.status == TBLoginItemDisabled)) return YES;
        return enabled ? [SMAppService.mainAppService registerAndReturnError:error]
                       : [SMAppService.mainAppService unregisterAndReturnError:error];
    }
    if (error) *error = [NSError errorWithDomain:@"TouchBarControl.LoginItem" code:1
                                      userInfo:@{NSLocalizedDescriptionKey:@"Launch at login requires macOS 13 or later."}];
    return NO;
}
@end
