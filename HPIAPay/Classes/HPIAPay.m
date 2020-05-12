//
//  HPIAPay.m
//  HPFeatureSet
//
//  Created by HP on 2018/6/9.
//  Copyright © 2018年 HP. All rights reserved.
//

#import "HPIAPay.h"
#import <StoreKit/StoreKit.h>// 1.首先导入支付包 StoreKit.framework

typedef void(^RequestCompleteBlock)(NSArray <HPIAPProduct *>*products,NSError *error);
typedef void(^PayCompleteBlock)(bool succeeded, NSString *errorMessage);

@interface HPIAPay () <SKPaymentTransactionObserver,SKProductsRequestDelegate>// 2.设置代理服务
@property (nonatomic,copy) RequestCompleteBlock requestCallBackBlock;
@property (nonatomic,copy) PayCompleteBlock payCallBackBlock;
@property (nonatomic,strong) NSArray <SKProduct *> *productsAry;
@property (nonatomic) BOOL isUsable;
@end

@implementation HPIAPay

+ (HPIAPay *)shareInstance {
    @synchronized (self) {
        static HPIAPay *_manager = nil;
        static dispatch_once_t oncePredicate;
        dispatch_once(&oncePredicate, ^{
            _manager = [[HPIAPay alloc] init];
            _manager.isUsable = NO;
        });
        return _manager;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 3.设置支付服务(设置后才能回调支付结果方法-paymentQueue::)
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [HPIAPay shareInstance];
}


- (void)setLogUsable:(BOOL)usable {
    self.isUsable = usable;
}

//4.结束后一定要销毁
- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    self.requestCallBackBlock = nil;
    self.payCallBackBlock = nil;
}

// 5.点击按钮的时候判断app是否允许apple支付
- (BOOL)canMakePayments {
    return [SKPaymentQueue canMakePayments];
}

// 6.请求苹果后台商品
- (void)productsWithIdentifier:(NSArray *)indentifiers complete:(void(^)(NSArray <HPIAPProduct *>*products,NSError *error))completeblock {
    //如果app允许applepay
    if ([self canMakePayments]) {
        self.requestCallBackBlock = completeblock;
        
        // 7.这里的indentifiers就对应着苹果后台的商品ID,他们是通过这个ID进行联系的。
        NSSet *nsset = [NSSet setWithArray:indentifiers];
        
        // 8.初始化请求
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
        request.delegate = self;
        
        // 9.开始请求
        [request start];
    }else {
        if (completeblock != nil) {
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey:@"获取商品失败",
                                       NSLocalizedFailureReasonErrorKey:@"原因：应用不允许苹果支付",
                                       NSLocalizedRecoverySuggestionErrorKey:@"恢复建议：在系统设置中允许应用程序使用苹果内支付功能"};
            NSError *error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:1001 userInfo:userInfo];
            completeblock(nil,error);
        }
    }
}

// 12.发送购买请求
- (void)payWithProduct:(HPIAPProduct *)product result:(void(^)(bool succeeded, NSString *errorMessage))resultBlock {
    if (product == nil) {
        resultBlock(false,@"产品对象为nil");
        return;
    }
    if (resultBlock != nil) {
        self.payCallBackBlock = resultBlock;
    }
    NSString *identifier = product.productIdentifier;
    for (SKProduct *pro in self.productsAry) {
        if (pro.productIdentifier == identifier) {
            [self payAction:pro];
            break;
        }
    }
}

-(void)payAction:(SKProduct *)product {
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

#pragma mark - SKProductsRequestDelegate
// 10.接收到产品的返回信息,然后用返回的商品信息进行发起购买请求
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *products = response.products;
    
    if(products.count == 0){
        if (self.requestCallBackBlock != nil) {
            self.requestCallBackBlock(@[], nil);
        }
        return;
    }
    
    self.productsAry = products;
    NSMutableArray *mutArray = [NSMutableArray array];
    for (SKProduct *pro in products) {
        HPIAPProduct *model = [[HPIAPProduct alloc] init];
        model.desc = pro.description;
        model.localizedDescription = pro.localizedDescription;
        model.localizedDescription = pro.localizedDescription;
        model.price = pro.price;
        model.productIdentifier = pro.productIdentifier;
        [mutArray addObject:model];
    }
    
    if (self.requestCallBackBlock != nil) {
        self.requestCallBackBlock(mutArray.copy, nil);
    }
}
#pragma mark -SKRequestDelegate

//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    if (self.requestCallBackBlock != nil) {
        self.requestCallBackBlock(nil, error);
    }
    if(_isUsable) NSLog(@"---error:%@", error);
}

//反馈请求的产品信息结束后
- (void)requestDidFinish:(SKRequest *)request{
    if(_isUsable) NSLog(@"---请求产品信息已结束");
}

#pragma mark - SKPaymentTransactionObserver

// 13.监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction{
    for(SKPaymentTransaction *tran in transaction){
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                if(_isUsable) NSLog(@"---商品加入列表，正在购买中...");
                break;
            case SKPaymentTransactionStatePurchased: {
                [queue finishTransaction:tran];
                if (self.payCallBackBlock != nil) {
                    self.payCallBackBlock(true, @"交易完成");
                }
                break;
            }
            case SKPaymentTransactionStateRestored: {
                [queue finishTransaction:tran];
                if (self.payCallBackBlock != nil) {
                    self.payCallBackBlock(true, @"恢复购买");
                }
                break;
            }
            case SKPaymentTransactionStateFailed: {
                if(_isUsable) NSLog(@"----StateFailed error = %@",tran.error);
                [queue finishTransaction:tran];
                if (self.payCallBackBlock != nil) {
                    self.payCallBackBlock(false, tran.error.description);
                }
                break;
            }
            default: {
                if(_isUsable) NSLog(@"----error = %@",tran.error);
                [queue finishTransaction:tran];
                if (self.payCallBackBlock != nil) {
                    self.payCallBackBlock(false, tran.error.description);
                }
                break;
            }
        }
    }
}


#pragma mark - 支付成功后获取订单

- (NSData *)fetchReceipt {
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 从沙盒中获取到购买凭据
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    // 传输的是BASE64编码的字符串
    /**
     BASE64 常用的编码方案，通常用于数据传输，以及加密算法的基础算法，传输过程中能够保证数据传输的稳定性
     BASE64是可以编码和解码的
     */
    NSDictionary *requestContents = @{@"receipt-data": [receipt base64EncodedStringWithOptions:0]};
    // 转换为 JSON 格式
    NSError *error;
    NSData *receiptData = [NSJSONSerialization dataWithJSONObject:requestContents options:0 error:&error];
    return receiptData;
}

#pragma mark - 客户端验证购买凭据

/*
 苹果反馈的状态码；
 0     鉴定成功
 21000 App Store无法读取你提供的JSON数据
 21002 收据数据不符合格式
 21003 收据无法被验证
 21004 你提供的共享密钥和账户的共享密钥不一致
 21005 收据服务器当前不可用
 21006 收据是有效的，但订阅服务已经过期。当收到这个信息时，解码后的收据信息也包含在返回内容中
 21007 收据信息是测试用（sandbox），但却被发送到产品环境中验证
 21008 收据信息是产品环境中使用，但却被发送到测试环境中验证
 */
- (void)verifyTransactionWithReceiptData:(NSData *)data complete:(void (^)(NSDictionary * _Nullable dict, NSError * _Nullable error))completeBlcok {
    if (!data) { /* ... Handle error ... */ return; }
    
    // 发送网络POST请求，对购买凭据进行验证
    NSString *verifyUrlString;
#if (defined(APPSTORE_ASK_TO_BUY_IN_SANDBOX) && defined(DEBUG))
    verifyUrlString = @"https://sandbox.itunes.apple.com/verifyReceipt";
#else
    verifyUrlString = @"https://buy.itunes.apple.com/verifyReceipt";
#endif
    __weak typeof(self) weakSelf = self;
    NSURL *url = [NSURL URLWithString:verifyUrlString];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) { // 当前是子线程.
        
        if (error) {
            if(weakSelf.isUsable) NSLog(@"---error:%@ %ld", error.localizedDescription,(long)error.code);
            completeBlcok(nil,error);
        }else if (data != nil && [data isKindOfClass:[NSNull class]] == NO) {
            NSError *err;
            NSDictionary *jsonResult = nil;
            jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&err];
            completeBlcok(jsonResult,nil);
            
            // 比对 jsonResponse 中以下信息基本上可以保证数据安全
            /*
             bundle_id
             application_version
             product_id
             transaction_id
             */
            
        }else {
            completeBlcok(nil,nil);
            if(weakSelf.isUsable) NSLog(@"---httpAsynchronousRequest:异步返回信息错误");
        }
    }];
    [task resume];
    
    /*
    
    // 国内访问苹果服务器比较慢，timeoutInterval 需要长一点
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:[[NSURL alloc] initWithString:verifyUrlString] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:data];
    // 在后台对列中提交验证请求，并获得官方的验证JSON结果
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   NSLog(@"链接失败");
                               } else {
                                   NSError *error;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                   if (!jsonResponse) {
                                       NSLog(@"验证失败");
                                   }
                                   NSLog(@"验证成功");
                               }
                           }];
     
     */
    
}

#if 0

// ios7前，获取订单信息的方式

- (void)verifyTransaction:(SKPaymentTransaction *)transaction {
    
    NSString *str = [[NSString alloc]initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding];
    NSString *environment = [self environmentForReceipt:str];
    if(_isUsable) NSLog(@"----- 完成交易调用的方法completeTransaction 1--------%@",environment);
    NSURL *StoreURL=nil;
    if ([environment isEqualToString:@"environment=Sandbox"]) {
        StoreURL= [[NSURL alloc] initWithString: @"https://sandbox.itunes.apple.com/verifyReceipt"];
    }else{
        StoreURL= [[NSURL alloc] initWithString: @"https://buy.itunes.apple.com/verifyReceipt"];
    }
    
    // do next ..
    
}

- (NSString *)environmentForReceipt:(NSString *)str {
    str= [str stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    str = [str stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    str=[str stringByReplacingOccurrencesOfString:@" " withString:@""];
    str=[str stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    NSArray * arr = [str componentsSeparatedByString:@";"];
    //存储收据环境的变量
    if (arr.count > 2) {
        return arr[2];
    }
    return arr.lastObject;
}

#endif

@end

@implementation HPIAPProduct
@end
