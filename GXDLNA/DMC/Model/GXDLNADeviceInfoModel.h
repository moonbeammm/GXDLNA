//  GXDLNADeviceInfoModel.h
//
//  Created by sgx on 2019/11/28.
//

#import <Foundation/Foundation.h>

@interface GXDLNADeviceInfoModel : NSObject

//设备uuid
@property(nonatomic, copy)NSString *uuid;
//设备名称
@property(nonatomic, copy)NSString *name;
//生产商
@property (nonatomic, retain) NSString *manufacturer;
//型号名
@property (nonatomic, retain) NSString *modelName;
//型号编号
@property (nonatomic, retain) NSString *modelNumber;
//设备生产串号
@property (nonatomic, retain) NSString *serialNumber;
//设备地址
@property (nonatomic, copy) NSString *descriptionURL;
//设备IP地址
@property (nonatomic, copy) NSString *ip;
//设备端口号
@property (nonatomic, copy) NSString *port;

@end
