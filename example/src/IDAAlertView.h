#import <UIKit/UIKit.h>

/**
 * AlertView wrapper with blocky interface.
 */
@interface IDAAlertView : UIAlertView <UIAlertViewDelegate>

- (void)addBlock:(void(^)(void))block forButtonIndex:(NSInteger)index;

@end

/* vim: set ts=8 sw=4 tw=0 ft=objc :*/
