#import <Foundation/Foundation.h>

@class SSDP;

static const NSString  *SSDP_DISCOVER_IP      = @"239.255.255.250";
static const NSUInteger SSDP_DISCOVER_PORT    = 1900;

static const NSString  *SSDP_DISCOVER_DEVICES = @"M-SEARCH * HTTP/1.1\r\n\
HOST: %@:%d\r\n\
Man: \"ssdp:discover\"\r\n\
MX: 1\r\n\
ST: urn:dial-multiscreen-org:device:dial:1\r\n\
\r\n";

@protocol SSDPDelegate <NSObject>
- (void) browser:(SSDP *)browser foundService:(NSDictionary *)service;
@end

@interface SSDP : NSObject

@property(nonatomic, weak) id<SSDPDelegate> delegate;

- (id) initWithDelegate:(id<SSDPDelegate>)delegate;

- (void)startScanning;
- (void)stopScanning;

@end
