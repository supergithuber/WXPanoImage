//
//  WXPanoImageViewController.h
//  WXPanoImage
//
//  Created by 吴浠 on 2018/8/12.
//  Copyright © 2018年 吴浠. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface WXPanoImageViewController : GLKViewController

@property (nonatomic, copy) NSString        *imageName;
@property (nonatomic, copy) NSString        *imageType;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithImageName:(NSString *)imageName type:(NSString *)imageType;

@end
