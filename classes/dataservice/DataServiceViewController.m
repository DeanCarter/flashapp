//
//  FirstViewController.m
//  flashapp
//
//  Created by 李 电森 on 11-12-12.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "DataServiceViewController.h"
#import "DatasaveViewController.h"
#import "RegisterViewController.h"
#import "SimpleViewController.h"
#import "StatsDayService.h"
#import "StatsMonthDAO.h"
#import "StageStats.h"
#import "DateUtils.h"
#import "DBConnection.h"
#import "StringUtil.h"
#import "AppDelegate.h"
#import "UIDevice-Reachability.h"
#import "OpenUDID.h"

@implementation DataServiceViewController

@synthesize monthLable;
@synthesize totalUseLable;
@synthesize netLable;
@synthesize upgradeButton;
@synthesize sampleButton;
@synthesize profileButton;
@synthesize shareButton;
@synthesize totalStats;
@synthesize monthStats;
@synthesize userAgentStatsList;
@synthesize userAgentView1;
@synthesize userAgentView2;
@synthesize userAgentBgView;


#pragma mark - init & destroy

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"飞速FlashApp";
        self.tabBarItem.title = @"服务";
        self.tabBarItem.image = [UIImage imageNamed:@"icon_service.png"];
        timer = nil;
    }
    return self;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}


- (void) dealloc
{
    [monthLable release];
    [totalUseLable release];
    [netLable release];
    [totalStats release];
    [monthStats release];
    [userAgentStatsList release];
    [upgradeButton release];
    [sampleButton release];
    [profileButton release];
    [shareButton release];
    [userAgentView1 release];
    [userAgentView2 release];
    [userAgentBgView release];
    [super dealloc];
}


#pragma mark - loadData

- (void) loadData:(BOOL)downFromServer
{
    if ( downFromServer ) {
        [StatsDayService explainURL];
    }
    
    [DBConnection beginTransaction];
    //得到节省流量的总数
    self.totalStats = [StatsMonthDAO statForPeriod:0 endTime:0];
    
    if ( totalStats ) {
        //得到本月节省的流量
        time_t now;
        time( &now );
        time_t firstDayOfMonth = [DateUtils getFirstDayOfMonth:now];
        time_t lastDayOfMonth = [DateUtils getLastDayOfMonth:now];
        self.monthStats = [StatsMonthDAO statForPeriod:firstDayOfMonth endTime:lastDayOfMonth];
        
        //得到节省流量最高的应用
        self.userAgentStatsList = [StatsMonthDAO userAgentStatsForPeriod:0 endTime:0 orderby:@"compress" limit:5];
    }

    [DBConnection commitTransaction];
}


- (void) checkConnection 
{
    ConnectionType type = [UIDevice connectionType]; 
    NSString* desc = nil;
    
    switch (type) {
        case UNKNOWN:
            desc = @"网络无链接,请检查网络";
            break;
        case CELL_2G:
            desc = @"飞速FlashApp正在加速网络通道，并为您节省流量";
            break;
        case CELL_3G:
            desc = @"飞速FlashApp正在加速网络通道，并为您节省流量";
            break;
        case CELL_4G:
            desc = @"飞速FlashApp正在加速网络通道，并为您节省流量";
            break;
        case WIFI:
            desc = @"现在正在使用无线网络，飞速软件暂停一下...";
            break;
        case NONE:
            desc = @"网络无链接,请检查网络";
            break;
        case ETHERNET:
            desc = @"Ethernet connection";
            break;
        default:
            desc = @"";
            break;
    }

    self.netLable.text = desc;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    refreshLock = [[NSLock alloc] init];
    self.navigationItem.titleView.backgroundColor = [UIColor blackColor];
    
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"帮助" style:UIBarButtonItemStylePlain target:self action:@selector(showHelp)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(pressRefresh)] autorelease];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    userAgentBgView = [[UIView alloc] initWithFrame:CGRectMake(10, 10, 300, 85)];
    [self.view addSubview:userAgentBgView];
    
    userAgentView1 = [[UserAgentTotalStatsView alloc] initWithFrame:CGRectMake(0, 0, 300, 85)];
    [userAgentBgView addSubview:userAgentView1];
    
    userAgentView2 = [[UserAgentTotalStatsView alloc] initWithFrame:CGRectMake(0, 0, 300, 85)];
    [userAgentBgView addSubview:userAgentView2];

    [self drawLineStyle];
    [self refresh:NO];
    
    justLoaded = YES;
}


- (void) viewShowData
{
    if ( [userAgentStatsList count] > 0 ) {
        float i = [AppDelegate getAppDelegate].user.capacity;
        if (i==0) i = QUANTITY_INIT;
        float capacity = i * 1024L * 1024L;
        
        long monthCompress = monthStats.bytesBefore - monthStats.bytesAfter;
        long leftCapacity = capacity - monthCompress;
        if ( leftCapacity < 0 ) leftCapacity = 0;
        
        NSString* s = [NSString stringWithFormat:@"本月已处理%@, 余%@.", [NSString stringForByteNumber:monthStats.bytesBefore], [NSString stringForByteNumber:leftCapacity]];
        self.monthLable.text = s;
        
        UIFont* font = [UIFont systemFontOfSize:12];
        CGSize size = [s sizeWithFont:font];
        CGRect rect = monthLable.frame;
        rect.size.width = size.width;
        monthLable.frame = rect;
        
        //提示升级
        accountStatus status = [AppDelegate getAppDelegate].user.status;
        //if ( status == STATUS_NEW || status == STATUS_INSTALLED || status == STATUS_REGISTERED ) {
        //    upgradeButton.hidden = NO;
        //    upgradeButton.frame = CGRectMake( 20 + size.width, 98, 70, 25 );
        //}
        //else {
        //    upgradeButton.hidden = YES;
        //}
        upgradeButton.hidden = YES;
        
        if ( [userAgentStatsList count] > 0 ) {
            currentStatsViewIndex = 0;
            currentUserAgentIndex = 0;
            [self showUserAgentStatsView];
        }
        
        s = [NSString stringForByteNumber:(totalStats.bytesBefore - totalStats.bytesAfter)];
        self.totalUseLable.text = [NSString stringWithFormat:@"到目前为止,总共节省了%@.", s];
        
        if ( [userAgentStatsList count] > 1 ) {
            if ( timer ) {
                [timer invalidate];
            }
            timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(animateUserAgentView) userInfo:nil repeats:YES];
        }
    }
    else {
        [self showSample];
    }
    
    //提示安装profile文件
    [self showConnectMessage];
}


-(void)drawLineStyle
{
    imageView=[[[UIImageView alloc] initWithFrame:self.view.frame] autorelease];  
    [self.view addSubview:imageView];  
    
    UIGraphicsBeginImageContext(imageView.frame.size);  
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 0.3);  
    CGContextSetAllowsAntialiasing(UIGraphicsGetCurrentContext(), YES);      
    
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), 0.0, 0.0, 0.0, 1.0);  
    CGContextBeginPath(UIGraphicsGetCurrentContext());  
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), 20, 100);  
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), 300, 100);  
    CGContextStrokePath(UIGraphicsGetCurrentContext());  
    imageView.image=UIGraphicsGetImageFromCurrentImageContext();  
    UIGraphicsEndImageContext();  
 }


- (void)viewDidUnload
{
    [super viewDidUnload];
    self.monthLable = nil;
    self.totalUseLable = nil;
    self.netLable = nil;
    self.totalStats = nil;
    self.monthStats = nil;
    self.userAgentStatsList = nil;
    self.upgradeButton = nil;
    self.sampleButton = nil;
    self.profileButton = nil;
    self.shareButton = nil;
    self.userAgentView1 = nil;
    self.userAgentView2 = nil;
    self.userAgentBgView = nil;
    
    if ( timer ) [timer invalidate];
    timer = nil;
    [refreshLock release];
    refreshLock = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ( justLoaded ) {
        [self performSelector:@selector(pressRefresh) withObject:nil afterDelay:0.5];
        justLoaded = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    //[userAgentView1 setNeedsLayout];
    //[userAgentView1 setNeedsDisplay];
    //[userAgentView2 setNeedsLayout];
    //[userAgentView2 setNeedsDisplay];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}


#pragma mark - operation methods


- (void) showConnectMessage
{
    //提示安装profile文件
    InstallFlag proxyFlag = [AppDelegate getAppDelegate].user.proxyFlag;
    if ( proxyFlag == INSTALL_FLAG_NO ) {
        self.netLable.text = @"您的授权文件没有安装，请        ";
        self.profileButton.hidden = NO;
    }
    else {
        [self checkConnection];
        self.profileButton.hidden = YES;
    }
}


- (void) showSample
{
    monthLable.hidden = YES;
    upgradeButton.hidden = YES;
    userAgentBgView.hidden = YES;
    
    totalUseLable.lineBreakMode = UILineBreakModeCharacterWrap;
    totalUseLable.numberOfLines = 100;
    NSString* s = @"飞速（flashApp）是国内技术领先得网络加速软件，网络访问速度可提升3－10倍，并可节约40％－85％得网络流量，让网速飞，省钱看得见。";
    totalUseLable.text = s;
    totalUseLable.frame = CGRectMake( 20, 20, 280, 80 );
    
    sampleButton.hidden = NO;
    sampleButton.frame = CGRectMake( 230, 65, 58, 21);
}


- (IBAction) openSampleView
{
    SimpleViewController* controller = [[SimpleViewController alloc] init];
    [self.navigationController presentModalViewController:controller animated:YES];
    [controller release];
}


- (void) showUserAgentStatsView
{
    monthLable.hidden = NO;
    userAgentBgView.hidden = NO;
    sampleButton.hidden = YES;
    totalUseLable.frame = CGRectMake( 20, 116, 281, 24 );
    
    UserAgentTotalStatsView* currentView = nil;
    UserAgentTotalStatsView* nextView = nil;
    if ( currentStatsViewIndex == 0 ) {
        currentView = userAgentView1;
        nextView = userAgentView2;
        currentStatsViewIndex = 1;
    }
    else {
        currentView = userAgentView2;
        nextView = userAgentView1;
        currentStatsViewIndex = 0;
    }
    
    StatsDetail* currentStatsDetail = [userAgentStatsList objectAtIndex:currentUserAgentIndex];
    
    currentUserAgentIndex++;
    if ( currentUserAgentIndex >= [userAgentStatsList count] ) {
        currentUserAgentIndex = 0;
    }

    StatsDetail* nextStatsDetail = [userAgentStatsList objectAtIndex:currentUserAgentIndex];
    
    currentView.hidden = NO;
    //currentView.userInteractionEnabled = YES;
    [currentView setStats:currentStatsDetail];
    
    nextView.hidden = YES;
    //nextView.userInteractionEnabled = NO;
    [nextView setStats:nextStatsDetail];
}


- (void) animateUserAgentView
{
	// Set up the animation
	CATransition *animation = [CATransition animation];
	animation.delegate = self;
	animation.duration = 0.8f;
	animation.timingFunction = UIViewAnimationCurveEaseInOut;
    //animation.timingFunction = UIViewAnimationCurveEaseIn;
	
    //animation.type = kCATransitionFade;
    animation.type = kCATransitionPush;
    //animation.type = kCATransitionMoveIn;
    //animation.type = kCATransitionReveal;
    //animation.subtype = kCATransitionFromBottom;
    animation.subtype = kCATransitionFromLeft;

    [self showUserAgentStatsView];
	// Perform the animation
	[[userAgentBgView layer] addAnimation:animation forKey:@"animation"];
    
    //[self performSelector:@selector(animateUserAgentView) withObject:nil afterDelay:5];
}



- (IBAction) shareToFriends
{
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"邀请好友" message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"发送邮件",@"发送短信", nil];
    [alertView show];
    [alertView release];
}


- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString* subject = @"我正在用FlashApp节省流量呢";
    NSString* text = [NSString stringWithFormat:@"发现飞速FlashApp真不错，能让应用加速，还能节省流量呢！http://%@/invite?uuid=%@", P_HOST, [OpenUDID value]];
    if ( buttonIndex == 1 ) {
        [self sendMail:subject body:text];
    }
    else if ( buttonIndex == 2 ) {
        [self sendSMS:text];
    }
}


- (void) showHelp
{
    //[AppDelegate showHelp];
    DatasaveViewController* controller = [[DatasaveViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}


- (IBAction) installProfile
{
    [AppDelegate installProfile:@"current"];
}


- (IBAction) upgrade
{
    RegisterViewController* controller = [[RegisterViewController alloc] init];
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:controller];
    controller.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"放弃" style:UIBarButtonItemStylePlain target:controller action:@selector(skip)];
    [self.navigationController presentModalViewController:nav animated:YES];
    [controller release];
    [nav release];
}


- (void) pressRefresh
{
    [self refresh:YES];
}

- (void) refresh:(BOOL)downFromServer
{
    if ( [refreshLock tryLock] ) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
        
        [self loadData:downFromServer];
        [self viewShowData];
        
        //提示安装profile文件
        [self showConnectMessage];
        
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [refreshLock unlock];
    }
}

#pragma mark - sms methods

- (void) sendSMS:(NSString*)body
{
	Class messageClass = (NSClassFromString(@"MFMessageComposeViewController"));
	if (messageClass != nil) {
		// Check whether the current device is configured for sending SMS messages
		if ([messageClass canSendText]) {
			[self displaySMSComposerSheet:body];
		}
		else {
            [AppDelegate showAlert:@"设备没有短信功能" message:@"您的设备不能发送短信"];
		}
	}
	else {
        [AppDelegate showAlert:@"iOS版本过低" message:@"iOS版本过低,iOS4.0以上才支持程序内发送短信"];
	}
}


- (void) displaySMSComposerSheet:(NSString*)body
{
	MFMessageComposeViewController *picker = [[MFMessageComposeViewController alloc] init];
	picker.messageComposeDelegate = self;
	picker.body = body;
    picker.title = @"发送短信";
    
    [self.navigationController presentModalViewController:picker animated:YES];
	[picker release];
}


- (void)messageComposeViewController:(MFMessageComposeViewController *)messageComposeViewController
				 didFinishWithResult:(MessageComposeResult)result {
	switch (result)
	{
		case MessageComposeResultCancelled:
			break;
		case MessageComposeResultSent:
            [AppDelegate showAlert:@"短信已经成功发送！"];
			break;
		case MessageComposeResultFailed:
            [AppDelegate showAlert:@"抱歉，短信发送失败"];
			break;
		default:
			NSLog(@"Result: SMS not sent");
			break;
	}
    
    [self.navigationController dismissModalViewControllerAnimated:YES];
}


#pragma mark - email

- (void) sendMail:(NSString*)subject body:(NSString*)body
{
    NSString *mailTo = [NSString stringWithFormat:@"mailto:?subject=%@&body=%@",
                        [subject encodeAsURIComponent],
                        [body encodeAsURIComponent]];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:mailTo]];
}


- (void) viewTouchBegan:(UIView*)view
{
    NSLog(@"touch view!");
}

@end
