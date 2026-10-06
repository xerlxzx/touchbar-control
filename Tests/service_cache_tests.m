#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOMessage.h>

static NSUInteger assertions, lookups, registrations, ports, references;
static BOOL allowPort = YES, allowSource = YES, allowNotification = YES, failRetain;
static io_service_t nextService = 10;
static IOServiceInterestCallback callback;
static void *callbackContext;
static CFRunLoopSourceRef source;
static int portToken;
#define CHECK(condition) do { assertions++; if (!(condition)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); exit(1); } } while (0)

static IONotificationPortRef FakePortCreate(mach_port_t port) {
    (void)port;
    if (!allowPort) return NULL;
    ports++;
    CFRunLoopSourceContext context = {0};
    source = allowSource ? CFRunLoopSourceCreate(NULL, 0, &context) : NULL;
    return (IONotificationPortRef)&portToken;
}
static void FakePortDestroy(IONotificationPortRef port) {
    (void)port;
    ports--;
    if (source) CFRelease(source);
    source = NULL;
}
static CFRunLoopSourceRef FakeSource(IONotificationPortRef port) { (void)port; return source; }
static CFMutableDictionaryRef FakeMatch(const char *name) {
    CHECK(!strcmp(name, "backlight-dfr") || !strcmp(name, "IOHIDSystem"));
    return CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}
static io_service_t FakeLookup(mach_port_t port, CFDictionaryRef match) {
    (void)port;
    CFRelease(match);
    lookups++;
    if (nextService) references++;
    return nextService;
}
static kern_return_t FakeRetain(io_object_t object) {
    CHECK(object != 0);
    if (failRetain) { failRetain = NO; return kIOReturnError; }
    references++;
    return KERN_SUCCESS;
}
static kern_return_t FakeRelease(io_object_t object) {
    CHECK(object != 0 && references > 0);
    references--;
    return KERN_SUCCESS;
}
static kern_return_t FakeNotify(IONotificationPortRef port, io_service_t service, const io_name_t type,
                                IOServiceInterestCallback handler, void *context, io_object_t *notification) {
    (void)port; (void)service;
    CHECK(!strcmp(type, kIOGeneralInterest));
    registrations++;
    if (!allowNotification) return kIOReturnError;
    callback = handler;
    callbackContext = context;
    *notification = 100;
    references++;
    return KERN_SUCCESS;
}

// Compile the real cache against fake IOKit functions. No device access is linked.
#define IONotificationPortCreate FakePortCreate
#define IONotificationPortDestroy FakePortDestroy
#define IONotificationPortGetRunLoopSource FakeSource
#define IOServiceMatching FakeMatch
#define IOServiceNameMatching FakeMatch
#define IOServiceGetMatchingService FakeLookup
#define IOObjectRetain FakeRetain
#define IOObjectRelease FakeRelease
#define IOServiceAddInterestNotification FakeNotify
#import "../Sources/TBServiceCache.m"

int main(void) {
    @autoreleasepool {
        TBServiceCache *cache = [[TBServiceCache alloc] initWithName:"backlight-dfr" matchingClass:NO];
        io_service_t first = [cache copyService];
        io_service_t second = [cache copyService];
        CHECK(first == 10 && second == first && lookups == 1 && registrations == 1);
        CHECK(references == 4); // Cache, notification, and two caller references.
        FakeRelease(first);
        FakeRelease(second);
        callback(callbackContext, first, kIOMessageServicePropertyChange, NULL);
        CHECK(references == 2);
        callback(callbackContext, first, kIOMessageServiceIsTerminated, NULL);
        CHECK(references == 0);
        nextService = 11;
        io_service_t replacement = [cache copyService];
        CHECK(replacement == 11 && lookups == 2);
        FakeRelease(replacement);
        [cache invalidate];
        [cache invalidate];
        CHECK(references == 0);
        nextService = 0;
        CHECK([cache copyService] == 0);
        nextService = 12;
        replacement = [cache copyService];
        CHECK(replacement == 12 && lookups == 4);
        FakeRelease(replacement);
        failRetain = YES;
        nextService = 13;
        replacement = [cache copyService];
        CHECK(replacement == 13 && lookups == 5);
        FakeRelease(replacement);
        cache = nil;
        CHECK(references == 0 && ports == 0);

        // If notification setup fails, every request uses fresh discovery.
        allowNotification = NO;
        cache = [[TBServiceCache alloc] initWithName:"IOHIDSystem" matchingClass:YES];
        NSUInteger before = lookups;
        for (NSUInteger i = 0; i < 2; i++) {
            first = [cache copyService];
            CHECK(references == 1);
            FakeRelease(first);
        }
        CHECK(lookups == before + 2 && references == 0);
        cache = nil;
        CHECK(ports == 0);
        allowNotification = YES;
        for (NSNumber *missingPort in @[@YES, @NO]) {
            allowPort = !missingPort.boolValue;
            allowSource = missingPort.boolValue;
            cache = [[TBServiceCache alloc] initWithName:"IOHIDSystem" matchingClass:YES];
            before = registrations;
            first = [cache copyService];
            CHECK(references == 1 && registrations == before);
            FakeRelease(first);
            cache = nil;
            CHECK(references == 0 && ports == 0);
        }
        printf("PASS: %lu service-cache assertions. Fake IOKit only.\n", (unsigned long)assertions);
    }
    return 0;
}
