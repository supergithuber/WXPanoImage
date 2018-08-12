//
//  ViewController.m
//  WXPanoImage
//
//  Created by 吴浠 on 2018/8/11.
//  Copyright © 2018年 吴浠. All rights reserved.
//

#import "ViewController.h"
#import "WXPanoImageViewController.h"

@interface ViewController ()

@property (nonatomic, strong) WXPanoImageViewController *panoVc;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(100, 100, 50, 50);
    [button setBackgroundColor:[UIColor redColor]];
    [button addTarget:self action:@selector(push:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)push:(UIButton *)sender{
    [self.navigationController pushViewController:self.panoVc animated:YES];
}
- (WXPanoImageViewController *)panoVc{
    if (_panoVc == nil) {
        _panoVc  = [[WXPanoImageViewController alloc] initWithImageName:@"Room" type:@"jpg"];
        
    }
    return _panoVc;
}

@end
