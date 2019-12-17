//  GXDLNAResponseModel.h
//
//  Created by sgx on 2019/11/28.
//

#import <Foundation/Foundation.h>

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

/**
 动作解析响应
 */
@interface GXDLNAResponseModel : NSObject

@property (nonatomic, copy) NSString *deviceUUID;
@property (nonatomic, copy) NSString *serviceID;
@property (nonatomic, copy) NSString *eventName;
@property (nonatomic, copy) NSString *eventValue;

- (instancetype)initWithDeviceUUID:(NSString *)deviceUUID ServiceID:(NSString *)serviceID EventName:(NSString *)eventName EventValue:(NSString *)eventValue;

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

/**
 动作结果响应
 */
@interface GXDLNAResultResponseModel : NSObject

@property (nonatomic, assign) NSInteger result;
@property (nonatomic, copy) NSString *deviceUUID;
@property (nonatomic, assign) id userData;

- (instancetype)initWithResult:(NSInteger)result DeviceUUID:(NSString *)deviceUUID UserData:(id)userData;

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

/**
 当前动作响应
 */
@interface GXDLNACurTransportResponseModel : GXDLNAResultResponseModel

@property (nonatomic, strong) NSArray<NSString *> *actions;

- (instancetype)initWithResult:(NSInteger)result DeviceUUID:(NSString *)deviceUUID Actions:(NSArray<NSString *> *)actions UserData:(id)userData;

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@interface GXDLNAVolumResponseModel : GXDLNAResultResponseModel

@property (nonatomic, copy) NSString *channel;
@property (nonatomic, assign) NSInteger volume;

- (instancetype)initWithResult:(NSInteger)result DeviceUUID:(NSString *)deviceUUID UserData:(id)userData Channel:(NSString *)channel Volume:(NSInteger)volume;

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

/**
 当前投屏信息响应
 */
@interface GXDLNATransportInfoResponseModel : GXDLNAResultResponseModel

@property (nonatomic, copy) NSString *cur_transport_state;
@property (nonatomic, copy) NSString *cur_transport_status;
@property (nonatomic, copy) NSString *cur_speed;

@end

