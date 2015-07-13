#import "IDAAlertView.h"

@interface IDAAlertView ()
@property (nonatomic, strong) NSDictionary *blocks;
@end

@implementation IDAAlertView

- (void)addBlock:(void(^)(void))block forButtonIndex:(NSInteger)index
{
    self.delegate = self;
    NSMutableDictionary *mut = [self.blocks mutableCopy];
    if (!mut) mut = [NSMutableDictionary dictionary];
    [mut setObject:block forKey:[NSNumber numberWithInteger:index]];
    self.blocks = [mut copy];
}

- (void)alertView:(UIAlertView*)alert clickedButtonAtIndex:(NSInteger)index
{
    (void)alert;
    void (^block)(void) = [self.blocks objectForKey:[NSNumber numberWithInteger:index]];
    if (block) block();
}

#if TARGET_IPHONE_SIMULATOR

/**
 * Automatically dismiss alert and call block on iOS simulator.
 */
- (void)show
{
    [super show];
    [self dismissWithClickedButtonIndex:self.cancelButtonIndex animated:YES];
    void (^block)(void) = [self.blocks objectForKey:[NSNumber numberWithInteger:self.cancelButtonIndex]];
    if (!block) block = self.blocks.allValues.firstObject;
    if (block) block();
}

#endif

@end

/* vim: set ts=8 sw=4 tw=0 ft=objc :*/
