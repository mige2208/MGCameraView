//
//  ViewController.m
//  MGCameraViewDemo
//
//  Created by mige on 2018/5/16.
//  Copyright © 2018年 mige.com. All rights reserved.
//

#import "ViewController.h"
#import "MGCameraViewVC.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onButtonAction:(id)sender {
    MGCameraViewVC *vc = [[MGCameraViewVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
