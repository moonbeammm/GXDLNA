////  GXDLNAMediaControllerInterface.h
//  bilianime
//
//  Created by sgx on 2019/12/2.
//

#ifndef GXDLNAMediaControllerInterface_h
#define GXDLNAMediaControllerInterface_h

@class GXDLNACurTransportResponseModel;
@class GXDLNATransportInfoResponseModel;
@class GXDLNAResultResponseModel;
@class GXDLNAResponseModel;
@class GXDLNAVolumResponseModel;
@class GXDLNAPositionInfoModel;
@protocol GXDLNAMediaControllerInterface <NSObject>

@optional

/**
 发现并添加DMR(媒体渲染器)
 */
- (void)onDMRAdded;

/**
 移除DMR
 */
-(void)onDMRRemoved;

/**
 无DMR被选中
 */
- (void)noDMRBeSelected;

- (void)getCurrentAVTransportActionResponse:(GXDLNACurTransportResponseModel *)response;

- (void)getTransportInfoResponse:(GXDLNATransportInfoResponseModel *)response;

- (void)previousResponse:(GXDLNAResultResponseModel *)response;

- (void)nextResponse:(GXDLNAResultResponseModel *)response;

- (void)DMRStateViriablesChanged:(NSArray <GXDLNAResponseModel *> *)response;

- (void)playResponse:(GXDLNAResultResponseModel *)response;

- (void)pasuseResponse:(GXDLNAResultResponseModel *)response;

- (void)stopResponse:(GXDLNAResultResponseModel *)response;

- (void)setAVTransponrtResponse:(GXDLNAResultResponseModel *)response;

- (void)setVolumeResponse:(GXDLNAResultResponseModel *)response;

- (void)getVolumeResponse:(GXDLNAVolumResponseModel *)response;
- (void)delegateOnGetPositionInfoResult:(GXDLNAPositionInfoModel *)positionInfo;

/**
 获取seek结果
 */
- (void)OnSeekResult:(GXDLNAResultResponseModel *)result;
- (void)currentConnectionInfoResult:(GXDLNAResultResponseModel *)result;

@end

#endif /* GXDLNAMediaControllerInterface_h */
