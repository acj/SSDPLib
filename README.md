SSDPLib
=======

An Objective-C library for discovering SSDP network services and devices

## Basic usage

 * Instantiate SSDP via `-[SSDP initWithDelegate:]` and pass in a delegate
 * Call `-startScanning` on the instance
 * Wait for the delegate callback to notify you that a service has been discovered
 
## Support
This code is unsupported and is for reference only. Use at your own risk.
