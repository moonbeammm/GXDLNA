//  GXDLNADemoVC.m
//
//  Created by sgx on 2019/11/28.
//

#import "GXDLNADemoVC.h"
#import "GXDLNADMControl.h"

@interface GXDLNADemoVC ()
<
    UITableViewDelegate,
    UITableViewDataSource,
    GXDLNADMControlPlayDelegate,
    GXDLNADMControlSearchDelegate
>
{
    NSArray *_playList; //!< 播放数据源
    NSMutableArray<GXDLNADeviceInfoModel *> *_dataArray; //!< 所有搜索到的DMR
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIButton *closeConnect;
@property (weak, nonatomic) IBOutlet UIButton *reSearchBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopBtn;
@property (weak, nonatomic) IBOutlet UIButton *playNextBtn;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@end

@implementation GXDLNADemoVC

- (instancetype)init {
    self = [super init];
    if (self) {
        _playList = @[@"http://vjs.zencdn.net/v/oceans.mp4",
        @"https://media.w3.org/2010/05/sintel/trailer.mp4"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    // Do any additional setup after loading the view.
    
    [GXDLNADMControl shared].playDelegate = self;
    [GXDLNADMControl shared].searchDelegate = self;
    
    [self registerNotification];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // 启动DMC去搜索设备
    [[GXDLNADMControl shared] start];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // 停止DMC去搜索设备
    [[GXDLNADMControl shared] connectStop];
}

#pragma mark - GXDLNADMControlDelegate

- (void)dmc:(GXDLNADMControl *)dmc didFindServices:(NSArray<GXDLNADeviceInfoModel *> *)services {
    _dataArray = [services mutableCopy];
    for (GXDLNADeviceInfoModel *device in services) {
        self.infoLabel.text = [NSString stringWithFormat:@"%@-%@",self.infoLabel.text,device.name];
    }
    self.infoLabel.text = [NSString stringWithFormat:@"%@-%@",self.infoLabel.text,@"-new\n"];
    [self.tableView reloadData];
}

- (void)dmc:(GXDLNADMControl *)dmc playStatus:(GXDLNAPlayStatus)playStatus {
    if (playStatus == GXDLNAPlayStatusStopped) {
        [[GXDLNADMControl shared] renderStop];
    }
}

- (void)dmc:(GXDLNADMControl *)dmc currentTime:(NSTimeInterval)currentTime playableDuration:(NSTimeInterval)playableDuration duration:(NSTimeInterval)duration {
    NSLog(@"sgx >> currentTime:%@ duration:%@",@(currentTime).stringValue,@(duration).stringValue);
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class])];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:NSStringFromClass([UITableViewCell class])];
    }
    cell.textLabel.textColor = [UIColor blackColor];
    [cell.textLabel sizeToFit];
    [cell.textLabel setLineBreakMode:NSLineBreakByCharWrapping];
    [cell.textLabel setNumberOfLines:0];
    cell.textLabel.text = [_dataArray[indexPath.row] name];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.playBtn setTitle:@"暂停" forState:UIControlStateNormal];
    self.playBtn.selected = YES;
    [[GXDLNADMControl shared] chooseRenderWithUUID:[_dataArray[indexPath.row] uuid]];
    GXDLNADeviceInfoModel * model = [[GXDLNADMControl shared] getCurrentRender];
    self.infoLabel.text = [NSString stringWithFormat:@"%@",model.name];
    [self playWithUri:[_playList firstObject]];
}

#pragma mark - Private Method

- (void)playWithUri:(NSString *)uri {
    [[GXDLNADMControl shared] renderSetAVTransportWithURI:uri metaData:nil];
    [[GXDLNADMControl shared] renderPlay];
}

#pragma mark - Notification Method

/// 监听系统音量的变化
- (void)registerNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

/// 监听系统音量变化的回调
- (void)volumeChanged:(NSNotification *)noti {
    float systemVolume = [[noti.userInfo objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    [[GXDLNADMControl shared] renderSetVolume:(systemVolume*100)];
}

#pragma mark - Event Response
/// 重新搜索，刷新
- (IBAction)reSearchDevice:(id)sender {
    NSLog(@"投屏GXDLNADMControl:%s",__FUNCTION__);
    //删掉所有设备
    [_dataArray removeAllObjects];
    self.infoLabel.text = @"";
    //重启DMC
    [[GXDLNADMControl shared] connectStop];
    [[GXDLNADMControl shared] start];
}

- (IBAction)nextBtnHandle:(id)sender {
    
}

- (IBAction)playBtnHandle:(id)sender {
    self.playBtn.selected = !self.playBtn.isSelected;
    if (self.playBtn.isSelected) {
        [self.playBtn setTitle:@"暂停" forState:UIControlStateNormal];
        [[GXDLNADMControl shared] renderPlay];
    } else {
        [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
        [[GXDLNADMControl shared] renderPause];
    }
}

- (IBAction)stopBtnHandle:(id)sender {
    [[GXDLNADMControl shared] renderStop];
}

- (IBAction)closeConnectBtnHandle:(id)sender {
    self.infoLabel.text = @"";
    [[GXDLNADMControl shared] connectStop];
}

- (IBAction)seek:(UISlider *)sender {
    [[GXDLNADMControl shared] seekTo:sender.value*100];
}

@end
