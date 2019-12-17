//  GXDLNADeviceInfoModel.m
//
//  Created by sgx on 2019/11/28.
//

#import "GXDLNADeviceInfoModel.h"

@implementation GXDLNADeviceInfoModel

- (BOOL)isEqual:(GXDLNADeviceInfoModel *)object {
    return [self.uuid isEqualToString:object.uuid];
}

@end
