//  GXDLNAResponseModel.m
//
//  Created by sgx on 2019/11/28.
//

#import "GXDLNAResponseModel.h"

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@implementation GXDLNAResponseModel

- (instancetype)initWithDeviceUUID:(NSString *)deviceUUID ServiceID:(NSString *)serviceID EventName:(NSString *)eventName EventValue:(NSString *)eventValue
{
    if (self = [super init]) {
        self.deviceUUID = deviceUUID;
        self.serviceID = serviceID;
        self.eventName = eventName;
        self.eventValue = eventValue;
    }
    return self;
}

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@implementation GXDLNAResultResponseModel

- (instancetype)initWithResult:(NSInteger)result DeviceUUID:(NSString *)deviceUUID UserData:(id)userData
{
    if (self = [super init]) {
        self.result = result;
        self.deviceUUID = deviceUUID;
        self.userData = userData;
    }
    return self;
}

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@implementation GXDLNACurTransportResponseModel

- (instancetype)initWithResult:(NSInteger)result DeviceUUID:(NSString *)deviceUUID Actions:(NSArray<NSString *> *)actions UserData:(id)userData
{
    if (self = [super initWithResult:result DeviceUUID:deviceUUID UserData:userData]) {
        self.actions = actions;
    }
    return self;
}

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@implementation GXDLNAVolumResponseModel 

- (instancetype)initWithResult:(NSInteger)result DeviceUUID:(NSString *)deviceUUID UserData:(id)userData Channel:(NSString *)channel Volume:(NSInteger)volume
{
    if (self = [super initWithResult:result DeviceUUID:deviceUUID UserData:userData]) {
        self.channel = channel;
        self.volume = volume;
    }
    return self;
}

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@implementation GXDLNATransportInfoResponseModel


@end
