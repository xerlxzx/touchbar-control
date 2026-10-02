#import "TBServiceCache.h"
#import <IOKit/IOMessage.h>

static void TBServiceChanged(void *context, io_service_t service, natural_t message, void *argument) {
    (void)service; (void)argument;
    if (message == kIOMessageServiceIsTerminated)
        [(__bridge TBServiceCache *)context invalidate];
}

@implementation TBServiceCache {
    NSString *_name;
    BOOL _matchingClass;
    io_service_t _service;
    io_object_t _notification;
    IONotificationPortRef _port;
    CFRunLoopRef _runLoop;
}

- (instancetype)initWithName:(const char *)name matchingClass:(BOOL)matchingClass {
    if (!(self = [super init])) return nil;
    _name = [NSString stringWithUTF8String:name];
    _matchingClass = matchingClass;
    _port = IONotificationPortCreate(kIOMainPortDefault);
    CFRunLoopSourceRef source = _port ? IONotificationPortGetRunLoopSource(_port) : NULL;
    if (source) {
        _runLoop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());
        CFRunLoopAddSource(_runLoop, source, kCFRunLoopCommonModes);
    }
    return self;
}

- (io_service_t)copyService {
    if (_service) {
        if (IOObjectRetain(_service) == KERN_SUCCESS) return _service;
        [self invalidate];
    }
    CFMutableDictionaryRef match = _matchingClass ? IOServiceMatching(_name.UTF8String)
                                                  : IOServiceNameMatching(_name.UTF8String);
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, match);
    if (!service) return IO_OBJECT_NULL;
    // If termination cannot be observed, fall back to uncached lookups.
    if (_runLoop && IOServiceAddInterestNotification(_port, service, kIOGeneralInterest,
            TBServiceChanged, (__bridge void *)self, &_notification) == KERN_SUCCESS) {
        _service = service;
        IOObjectRetain(service);
    } else if (_notification) {
        IOObjectRelease(_notification);
        _notification = IO_OBJECT_NULL;
    }
    return service;
}

- (void)invalidate {
    if (_notification) IOObjectRelease(_notification);
    if (_service) IOObjectRelease(_service);
    _notification = IO_OBJECT_NULL;
    _service = IO_OBJECT_NULL;
}

- (void)dealloc {
    [self invalidate];
    if (_runLoop) {
        CFRunLoopRemoveSource(_runLoop, IONotificationPortGetRunLoopSource(_port), kCFRunLoopCommonModes);
        CFRelease(_runLoop);
    }
    if (_port) IONotificationPortDestroy(_port);
}
@end
