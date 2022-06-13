//
//  TBTViewController.m
//  TBTNetworkKit
//
//  Created by RainyofSun on 06/11/2022.
//  Copyright (c) 2022 RainyofSun. All rights reserved.
//

#import "TBTViewController.h"
#import "TBTDefaultServerRequest.h"

@interface TBTViewController ()<TBTResponseDelegate>

@property (nonatomic,strong) TBTDefaultServerRequest *request;

@end

@implementation TBTViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"开始网络请求");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self testNetwork1];
    });
}

- (void)testNetwork {
    [self.request start];
}

- (void)testNetwork1 {
    TBTDefaultServerRequest *request = [[TBTDefaultServerRequest alloc] init];
    request.requestMethod = TBTRequestMethod_POST;
    request.requestURI = @"toutiao/index";
    request.requestParameter = @{@"type":@"top",@"key":@"1556e6a8727672ced0deb4007782429c"};
    [request startWithSuccess:^(TBTNetworkResponse *response) {
        NSLog(@"response success : %@",response.responseObject);
    } failure:^(TBTNetworkResponse *response) {
        NSLog(@"response error : %@",response.error);
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSLog(@"%s",__func__);
}

- (void)dealloc {
    if (_request) {
        [_request cancel];
    }
    NSLog(@"%s",__func__);
}

#pragma mark - TBTResponseDelegate
- (void)request:(__kindof TBTBaseRequest *)request successWithResponse:(TBTNetworkResponse *)response {
    NSLog(@"response success : %@",response.responseObject);
}

- (void)request:(__kindof TBTBaseRequest *)request failureWithResponse:(TBTNetworkResponse *)response {
    NSLog(@"response error : %@",response.error);
}

- (TBTDefaultServerRequest *)request {
    if (!_request) {
        _request = [[TBTDefaultServerRequest alloc] init];
        _request.delegate = self;
        _request.requestMethod = TBTRequestMethod_GET;
        _request.requestURI = @"toutiao/index";
        _request.requestParameter = @{@"type":@"top",@"key":@"1556e6a8727672ced0deb4007782429c"};
        _request.repeatStrategy = TBTNetworkRepeatStrategy_CancelOldest;
    }
    return _request;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
