//
//  ViewController.m
//  DatabaseMigration
//
//  Created by Duyen Hoa Ha on 14/10/2014.
//  Copyright (c) 2014 Duyen Hoa Ha. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSString *escapedStr = @"Sorry, your search doesn\\u0027t have any result";
    NSString *unescapedStr = [NSString
                              stringWithCString:[escapedStr cStringUsingEncoding:NSUTF8StringEncoding]
                              encoding:NSNonLossyASCIIStringEncoding];
    NSLog(@"unescapedStr = %@", unescapedStr);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
