#include <stdio.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/types.h>

#import "SSDP.h"

@implementation SSDP
{
    BOOL             active;
	dispatch_queue_t ssdpScanQueue;
}

- (id)initWithDelegate:(id<SSDPDelegate>)delegate
{
	self = [super init];
	
	if (self)
	{
		_delegate = delegate;
		ssdpScanQueue = dispatch_queue_create("ssdp_scan_queue", DISPATCH_QUEUE_SERIAL);
	}
	
	return self;
}

- (void)startScanning
{
	active = YES;
	dispatch_async(ssdpScanQueue, ^{
		[self scanForSsdp];
	});
}

- (void)stopScanning
{
	active = NO;
}

- (void)scanForSsdp
{
    int sock = [self sendSsdpBroadcast];
    if (sock > 0)
    {
        [self receiveSsdpResponsesOnSocket:sock];
    }
}

- (int)sendSsdpBroadcast
{
    int sock;
	struct sockaddr_in destination;
	size_t echolen;
	
	/* Create the UDP socket */
	if ((sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0)
	{
		NSLog(@"Failed to create socket");
		return -1;
	}
	
	memset(&destination, 0, sizeof(destination));
    
	destination.sin_family      = AF_INET;
	destination.sin_addr.s_addr = inet_addr([SSDP_DISCOVER_IP UTF8String]);
	destination.sin_port        = htons(SSDP_DISCOVER_PORT);
	
	setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF, &destination, sizeof(destination));
    
	const char *cmsg = [[self discoverDeviceString] UTF8String];
	echolen = strlen(cmsg);
	
    int broadcast = 1;
	if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast)) == -1)
	{
		perror("setsockopt");
        return -1;
	}
    
	if (sendto(sock, cmsg, echolen, 0, (struct sockaddr *)&destination, sizeof(destination)) != echolen)
	{
		printf("Sent the wrong number of bytes\n");
		return -1;
	}
    
    return sock;
}

- (void)receiveSsdpResponsesOnSocket:(int)sock
{
	struct sockaddr_in myaddr;
    
    myaddr.sin_family = PF_INET;
	myaddr.sin_addr.s_addr = INADDR_ANY;
	myaddr.sin_port = htons(SSDP_DISCOVER_PORT);
	memset(&(myaddr.sin_zero), '\0', 8);
	
	fd_set          readfs;
	struct sockaddr addr;
	socklen_t       fromlen;
	char            buf[512];
	size_t          len = 0;
	
	FD_ZERO(&readfs);
	FD_SET(sock, &readfs);
    
	struct timeval timeout;
	timeout.tv_sec = 2;
	timeout.tv_usec = 500000;
	
    int n = sock + 1;
    
	while (YES)
    {
		int s = select(n, &readfs, NULL, NULL, &timeout);
		
		if (!active)
        {
			NSLog(@"Finished SSDP scan");
			close(sock);
			break;
		}
		
		if (s > 0)
        {
			if (FD_ISSET(sock, &readfs))
            {
				len = recvfrom(sock, &buf, sizeof(buf), 0, &addr, &fromlen);
				buf[len] = '\0';
				
				NSString *dataString = [[NSString alloc] initWithBytes:buf length:len encoding:NSUTF8StringEncoding];
				NSDictionary *serviceDict = [self serviceDictFromString:dataString];
				
				dispatch_async(dispatch_get_main_queue(), ^() {
					if ([self.delegate respondsToSelector:@selector(browser:foundService:)])
                    {
						[self.delegate browser:self foundService:serviceDict];
					}
				});
			}
		}
	}
}

- (NSString *)discoverDeviceString
{
    return [NSString stringWithFormat:(NSString *)SSDP_DISCOVER_DEVICES, SSDP_DISCOVER_IP, SSDP_DISCOVER_PORT];
}

- (NSDictionary *)serviceDictFromString:(NSString *)string
{
	NSArray             *lines       = [string componentsSeparatedByString:@"\n"];
	NSMutableDictionary *serviceDict = [NSMutableDictionary dictionary];
	
	for (NSString *line in lines)
    {
		NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		NSUInteger colonLocation = [trimmed rangeOfString:@":"].location;
		if (colonLocation == NSNotFound)
        {
			continue;
		}
		
		NSString *key   = [trimmed substringToIndex:colonLocation];
		NSString *value = nil;
		
		if (colonLocation + 1 < [trimmed length])
        {
			value = [trimmed substringWithRange:NSMakeRange(colonLocation + 1, [trimmed length] - (colonLocation + 1))];
		}
		
		if (key && value)
        {
			serviceDict[key] = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		}
	}
	
	return serviceDict;
}

@end
