//  GXDLNAPositionInfoModel.h
//
//  Created by sgx on 2019/12/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GXDLNAPositionInfoModel : NSObject
/**
 NPT_UInt32    track;
 NPT_TimeStamp track_duration;
 NPT_String    track_metadata;
 NPT_String    track_uri;
 NPT_TimeStamp rel_time;
 NPT_TimeStamp abs_time;
 NPT_Int32     rel_count;
 NPT_Int32     abs_count;
 */
@property (nonatomic, assign) int32_t result;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, assign) int64_t track;
@property (nonatomic, assign) int64_t duration;
@property (nonatomic, strong) NSString *metadata;
@property (nonatomic, strong) NSString *uri;
@property (nonatomic, assign) int64_t relTime;
@property (nonatomic, assign) int64_t absTime;
@property (nonatomic, assign) int64_t relCount;
@property (nonatomic, assign) int64_t absCount;
@end

NS_ASSUME_NONNULL_END
