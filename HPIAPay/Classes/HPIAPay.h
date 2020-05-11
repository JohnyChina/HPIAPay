//
//  HPIAPay.h
//  HPFeatureSet
//
//  Created by HP on 2018/6/9.
//  Copyright © 2018年 HP. All rights reserved.
//

/*
 ** 注：这里有几个注意事项
 
 一，测试支付的ipa必须使用[App-Store]证书;
 二，越狱机器无法测试IAP;
 三，用SandBox账号测试支付的时候,必须把在系统[设置]里面把[Itunes Store 与 App Store]登录的非SandBox账号注销掉,否则向苹果服务器请求不到订单信息;
 四，Sandbox账号不要在正式支付环境登陆支付，登陆过的正式支付环境的SandBox账号会失效;
 五，所有在itunes上配置的商品都必须可购买,不能有某些商品根据商户自己的服务器的数据在某个时期出现免费的情况;
 六，商品列表不能按照某些特定条件进行排序(比如说下载量);
 七，非消耗型商品必须的有恢复商品功能;
 八，非消耗类型的商品不要和商户自己的服务器关联;
 
 ** 异常：
 一，获取不到商品的原因：1.商品ID不对，2.Xcode的Capabilities中未打开内支付,3.签名证书不支持，4.iTunes后台没设置好收款银联卡.
 二，沙盒测试时，输入账号密码后没弹出【Sandbox ***】弹窗直播抛出SKPaymentTransactionStateFailed状态，报错【Domain=SKErrorDomain Code=0 "无法连接到 iTunes Store" UserInfo={NSLocalizedD】有可能是沙盒账号有问题。直接用一个正式Apple ID 试试。
 三、需要恢复购买的，要对应好iTunes connet后台配置的产品类型才可以！。
 */

#import <Foundation/Foundation.h>

// 苹果内购是否为沙盒测试账号,打开就代表为沙盒测试账号,注意上线时注释掉
#define APPSTORE_ASK_TO_BUY_IN_SANDBOX 0

@class HPIAPProduct;

@interface HPIAPay : NSObject

/**
 判断app是否允许apple支付

 @return 结果 YES=支持，NO=不支持
 */
- (BOOL)canMakePayments;

/**
 请求苹果后台商品

 @param indentifiers 商品ID
 @param completeblock 请求商品结果
 */
- (void)productsWithIdentifier:(NSArray * _Nonnull)indentifiers
                      complete:(void(^_Nullable)(NSArray <HPIAPProduct * >* _Nullable products,NSError * _Nonnull error))completeblock;

/**
 发送购买请求

 @param product <HPIAPProduct *>产品模型
 @param resultBlock 支付结果
 */
- (void)payWithProduct:(HPIAPProduct *_Nonnull )product
                result:(void(^_Nullable)(bool succeeded, NSString * _Nullable errorMessage))resultBlock;


/**
 交易成功后获取收据,已格式化。

 @return 返回值k是通过json格式化{"receipt-data":base64(receipt)}，可直接上传苹果服务器进行鉴定。
 */
- (NSData * _Nonnull)fetchReceipt;

/**
 检验收据的正确性，客户端向苹果服务器发起请求验证信息，并将结果json格式化返回。

 @param data 收据数据，每次交易成功后通过实例方法fetchReceipt获得。
 @param completeBlcok 子线程中返回验证结果
 */
- (void)verifyTransactionWithReceiptData:(NSData *_Nonnull)data complete:(void (^_Nullable)(NSDictionary * _Nullable dict, NSError * _Nullable error))completeBlcok;


@end

NS_ASSUME_NONNULL_BEGIN
@interface HPIAPProduct : NSObject
@property (nonatomic,copy) NSString *desc;                  // 产品描述
@property (nonatomic,copy) NSString *localizedTitle;        // 产品标题
@property (nonatomic,copy) NSString *localizedDescription;  // 本地化描述
@property (nonatomic,copy) NSNumber *price;                 // 额度（没有单位）
@property (nonatomic,copy) NSString *productIdentifier;     // 产品唯一标识符
@end
NS_ASSUME_NONNULL_END
