// AstralCheat dylib — inject into game, Astral UI design
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#include <cmath>
#include <vector>
#include <string>
#include <mutex>
#include <cstdint>

namespace Off {
    constexpr size_t Team=0x59, AimController=0x60, Weaponry=0x68, HitController=0x88;
    constexpr size_t MainCamera=0xC0, FpsCamera=0xC8;
    constexpr size_t PM_Dict=0x20, PM_HashSet=0x28, PM_LocalA=0x68, PM_LocalB=0x70;
    constexpr size_t SensX=0x50, SensY=0x54, FpsCamTr=0x70, CamTransform=0x80;
    constexpr size_t HeadAngles=0xA8, AimTargetVec=0x110;
    constexpr size_t WC_Float1=0x3C, WC_Float2=0x40, HealthFloat=0x18;
}

using Il2CppDomain=void*; using Il2CppAssembly=void*; using Il2CppImage=void*;
using Il2CppClass=void*; using Il2CppObject=void*; using Il2CppMethod=void*;
struct Il2CppApi {
    Il2CppDomain*(*domain_get)()=nullptr;
    Il2CppAssembly**(*domain_get_assemblies)(Il2CppDomain*,size_t*)=nullptr;
    Il2CppImage*(*assembly_get_image)(Il2CppAssembly*)=nullptr;
    Il2CppClass*(*class_from_name)(Il2CppImage*,const char*,const char*)=nullptr;
    Il2CppMethod*(*class_get_method_from_name)(Il2CppClass*,const char*,int)=nullptr;
    void*(*runtime_invoke)(Il2CppMethod*,void*,void**,void**)=nullptr;
    void*(*object_unbox)(Il2CppObject*)=nullptr;
};
static Il2CppApi gApi; static bool gIl2=false;
static void Il2Init(){
    if(gIl2)return;
#define L(n) gApi.n=(decltype(gApi.n))dlsym(RTLD_DEFAULT,"il2cpp_" #n)
    L(domain_get);L(domain_get_assemblies);L(assembly_get_image);
    L(class_from_name);L(class_get_method_from_name);L(runtime_invoke);L(object_unbox);
#undef L
    gIl2=gApi.domain_get&&gApi.class_from_name;
}
static Il2CppClass* FindClass(const char*ns,const char*name){
    if(!gIl2)return nullptr; size_t n=0;
    auto asms=gApi.domain_get_assemblies(gApi.domain_get(),&n); if(!asms)return nullptr;
    for(size_t i=0;i<n;i++){ auto img=gApi.assembly_get_image(asms[i]); if(!img)continue;
        auto c=gApi.class_from_name(img,ns,name); if(c)return c; } return nullptr;
}
template<typename T> static T Rd(void*o,size_t off){ return o?*reinterpret_cast<T*>((char*)o+off):T{}; }
template<typename T> static void Wr(void*o,size_t off,T v){ if(o)*reinterpret_cast<T*>((char*)o+off)=v; }

static BOOL gReady=NO,gMenu=NO;
static int gTab=0,gLang=0;
static float gAR=0.15f,gAG=0.55f,gAB=1.f;
static BOOL gAim=YES,gSilent=YES,gFovDraw=YES,gNoRecoil=YES;
static float gFov=15.f;
static BOOL gEsp=YES,gBox=YES,gName=YES,gHP=YES,gDist=YES,gSnap=NO,gTeam=YES,gHideRec=YES;
static NSString*gCfgName=@"default";

struct V3{float x,y,z;};
struct Ent{V3 pos,head;float hp,maxHp,dist;int team;bool local,dead;std::string name;};
static std::vector<Ent> gEnts; static std::mutex gMtx;
static void*gLocal=nullptr; static int gLocalTeam=0; static V3 gCamPos;

static NSString* T(NSString*ru,NSString*en){ return gLang==0?ru:en; }
static NSString* CfgRoot(){
    NSString*d=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject
                stringByAppendingPathComponent:@"AstralCheats"];
    [[NSFileManager defaultManager]createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
    return d;
}
static NSDictionary* CfgDict(){
    return @{@"aim":@(gAim),@"silent":@(gSilent),@"fovDraw":@(gFovDraw),@"fov":@(gFov),@"noRecoil":@(gNoRecoil),
             @"esp":@(gEsp),@"box":@(gBox),@"name":@(gName),@"hp":@(gHP),@"dist":@(gDist),@"snap":@(gSnap),
             @"team":@(gTeam),@"hideRec":@(gHideRec),@"lang":@(gLang)};
}
static void ApplyCfg(NSDictionary*d){
    if(![d isKindOfClass:NSDictionary.class])return;
    gAim=[d[@"aim"]boolValue]; gSilent=[d[@"silent"]boolValue]; gFovDraw=[d[@"fovDraw"]boolValue];
    gFov=fmaxf(1,fminf(30,[d[@"fov"]floatValue])); gNoRecoil=d[@"noRecoil"]?[d[@"noRecoil"]boolValue]:YES;
    gEsp=[d[@"esp"]boolValue]; gBox=[d[@"box"]boolValue]; gName=[d[@"name"]boolValue];
    gHP=[d[@"hp"]boolValue]; gDist=[d[@"dist"]boolValue]; gSnap=[d[@"snap"]boolValue];
    gTeam=[d[@"team"]boolValue]; gHideRec=[d[@"hideRec"]boolValue]; gLang=[d[@"lang"]intValue];
}
static void SaveCfg(){
    NSString*p=[[CfgRoot() stringByAppendingPathComponent:gCfgName]stringByAppendingPathExtension:@"json"];
    [[NSJSONSerialization dataWithJSONObject:CfgDict() options:0 error:nil]writeToFile:p atomically:YES];
}
static void LoadCfg(){
    NSString*p=[[CfgRoot() stringByAppendingPathComponent:gCfgName]stringByAppendingPathExtension:@"json"];
    NSData*d=[NSData dataWithContentsOfFile:p]; if(!d)return;
    ApplyCfg([NSJSONSerialization JSONObjectWithData:d options:0 error:nil]);
}

static Il2CppClass*s_tr=nullptr,*s_pm=nullptr; static Il2CppMethod*s_getPos=nullptr,*s_pmInst=nullptr;
static V3 InvV3(Il2CppMethod*m,void*o){
    if(!m||!o||!gApi.runtime_invoke)return{};
    void*e=nullptr; auto r=gApi.runtime_invoke(m,o,nullptr,&e);
    if(e||!r||!gApi.object_unbox)return{}; return *reinterpret_cast<V3*>(gApi.object_unbox(r));
}
static void GameTick(){
    Il2Init(); if(!gIl2)return;
    if(!s_tr){
        s_tr=FindClass("UnityEngine","Transform");
        s_pm=FindClass("","PlayerManager");
        if(s_tr)s_getPos=gApi.class_get_method_from_name(s_tr,"get_position",0);
        if(s_pm){ s_pmInst=gApi.class_get_method_from_name(s_pm,"get_Instance",0);
            if(!s_pmInst)s_pmInst=gApi.class_get_method_from_name(s_pm,"get_instance",0); }
    }
    if(!s_getPos)return;
    void*pm=nullptr;
    if(s_pmInst){ void*e=nullptr; pm=gApi.runtime_invoke(s_pmInst,nullptr,nullptr,&e); }
    if(!pm)return;
    void*local=Rd<void*>(pm,Off::PM_LocalA); if(!local)local=Rd<void*>(pm,Off::PM_LocalB);
    gLocal=local;
    if(local){
        gLocalTeam=(int)Rd<uint8_t>(local,Off::Team);
        void*aim=Rd<void*>(local,Off::AimController);
        if(aim){ void*tr=Rd<void*>(aim,Off::CamTransform); if(!tr)tr=Rd<void*>(aim,Off::FpsCamTr);
            if(tr)gCamPos=InvV3(s_getPos,tr); }
        if(gNoRecoil){ void*w=Rd<void*>(local,Off::Weaponry);
            if(w){ Wr<float>(w,Off::WC_Float1,0.f); Wr<float>(w,Off::WC_Float2,0.f); } }
    }
}

@interface ACW:UIWindow @end
@interface ACVC:UIViewController @end
@implementation ACVC
- (BOOL)shouldAutorotate{return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskLandscapeLeft|UIInterfaceOrientationMaskLandscapeRight;}
- (BOOL)prefersStatusBarHidden{return YES;}
@end

@class ACH;
static ACH*gHud=nil; static ACW*gWin=nil;

static UIWindow* GameWin(){
    UIWindow*best=nil; CGFloat area=0;
    for(UIWindow*w in UIApplication.sharedApplication.windows){
        if(w==gWin||w.hidden)continue;
        CGFloat a=w.bounds.size.width*w.bounds.size.height;
        if(a>area){area=a;best=w;}
    } return best;
}

@implementation ACW
- (BOOL)_isSecure{return gHideRec;}
- (BOOL)isSecure{return gHideRec;}
- (BOOL)_shouldCreateContextAsSecure{return gHideRec;}
- (UIView*)hitTest:(CGPoint)p withEvent:(UIEvent*)e{
    UIView*hit=[super hitTest:p withEvent:e];
    UIView*v=hit;
    while(v){ if(gHud&&(v==((ACH*)gHud).panel||v==((ACH*)gHud).fab))return hit; v=v.superview; }
    return nil;
}
@end

@interface ACH:UIView
@property(nonatomic,strong) CADisplayLink*link;
@property(nonatomic,strong) UIView*fab,*panel,*side;
@property(nonatomic,strong) UIScrollView*scroll;
@property(nonatomic,strong) UITextField*secureTF;
@property(nonatomic,strong) UIButton*langBtn;
- (void)rebuild; - (void)relayout; - (void)applyHide;
@end

@implementation ACH
- (UIColor*)neon{ return [UIColor colorWithRed:gAR green:gAG blue:gAB alpha:1]; }
- (UIColor*)cardBG{ return [UIColor colorWithRed:0.05 green:0.08 blue:0.14 alpha:0.95]; }
- (UIColor*)panelBG{ return [UIColor colorWithRed:0.03 green:0.05 blue:0.10 alpha:0.97]; }

- (instancetype)initWithFrame:(CGRect)f{
    self=[super initWithFrame:f]; if(!self)return nil;
    self.backgroundColor=UIColor.clearColor; self.opaque=NO; self.userInteractionEnabled=YES;
    CGFloat S=50;
    self.fab=[[UIView alloc]initWithFrame:CGRectMake(16,16,S,S)];
    self.fab.backgroundColor=[UIColor colorWithRed:0.06 green:0.12 blue:0.22 alpha:0.95];
    self.fab.layer.cornerRadius=S/2; self.fab.layer.borderWidth=2;
    self.fab.layer.borderColor=self.neon.CGColor;
    self.fab.layer.shadowColor=self.neon.CGColor; self.fab.layer.shadowOpacity=0.5; self.fab.layer.shadowRadius=8;
    UILabel*fl=[[UILabel alloc]initWithFrame:self.fab.bounds];
    fl.text=@"A"; fl.textAlignment=NSTextAlignmentCenter; fl.userInteractionEnabled=NO;
    fl.font=[UIFont systemFontOfSize:20 weight:UIFontWeightBlack]; fl.textColor=self.neon;
    [self.fab addSubview:fl];
    [self.fab addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(fabTap)]];
    [self.fab addGestureRecognizer:[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(fabPan:)]];
    [self addSubview:self.fab];

    self.panel=[[UIView alloc]initWithFrame:CGRectMake(0,0,620,340)];
    self.panel.backgroundColor=self.panelBG;
    self.panel.layer.cornerRadius=18; self.panel.layer.borderWidth=1.2;
    self.panel.layer.borderColor=[self.neon colorWithAlphaComponent:0.4].CGColor;
    self.panel.layer.shadowColor=self.neon.CGColor; self.panel.layer.shadowOpacity=0.25; self.panel.layer.shadowRadius=16;
    self.panel.clipsToBounds=YES; self.panel.hidden=YES; self.panel.userInteractionEnabled=YES;
    [self addSubview:self.panel];

    self.side=[[UIView alloc]initWithFrame:CGRectMake(0,0,150,340)];
    self.side.backgroundColor=[UIColor colorWithRed:0.02 green:0.04 blue:0.08 alpha:1];
    self.side.userInteractionEnabled=YES; [self.panel addSubview:self.side];

    UILabel*logo=[[UILabel alloc]initWithFrame:CGRectMake(8,14,134,36)];
    logo.text=@"ASTRAL"; logo.textAlignment=NSTextAlignmentCenter;
    logo.font=[UIFont systemFontOfSize:16 weight:UIFontWeightBlack]; logo.textColor=self.neon;
    logo.userInteractionEnabled=NO; [self.side addSubview:logo];
    UILabel*sub=[[UILabel alloc]initWithFrame:CGRectMake(8,42,134,14)];
    sub.text=@"CHEATS"; sub.textAlignment=NSTextAlignmentCenter;
    sub.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    sub.textColor=[UIColor colorWithRed:0.3 green:0.6 blue:1 alpha:0.8]; [self.side addSubview:sub];

    for(int i=0;i<4;i++){
        UIButton*b=[UIButton buttonWithType:UIButtonTypeSystem];
        b.frame=CGRectMake(10,70+i*44,130,38); b.tag=100+i; b.layer.cornerRadius=10;
        b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
        b.titleEdgeInsets=UIEdgeInsetsMake(0,12,0,0);
        b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        [b addTarget:self action:@selector(tab:) forControlEvents:UIControlEventTouchUpInside];
        [self.side addSubview:b];
    }
    self.langBtn=[UIButton buttonWithType:UIButtonTypeSystem];
    self.langBtn.frame=CGRectMake(10,290,130,32); self.langBtn.layer.cornerRadius=8;
    self.langBtn.backgroundColor=[UIColor colorWithWhite:0.08 alpha:1];
    self.langBtn.layer.borderWidth=1; self.langBtn.layer.borderColor=[UIColor colorWithWhite:0.2 alpha:1].CGColor;
    [self.langBtn setTitleColor:[UIColor colorWithWhite:0.7 alpha:1] forState:UIControlStateNormal];
    self.langBtn.titleLabel.font=[UIFont systemFontOfSize:12];
    self.langBtn.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    [self.langBtn addTarget:self action:@selector(togLang) forControlEvents:UIControlEventTouchUpInside];
    [self.side addSubview:self.langBtn];

    self.scroll=[[UIScrollView alloc]initWithFrame:CGRectMake(150,0,470,340)];
    self.scroll.alwaysBounceVertical=YES; self.scroll.delaysContentTouches=NO;
    [self.panel addSubview:self.scroll];
    [self.side addGestureRecognizer:[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panPanel:)]];
    [self rebuild];
    return self;
}

- (void)relayout{
    UIWindow*game=GameWin();
    if(gWin&&game){ gWin.transform=game.transform; gWin.bounds=game.bounds; gWin.center=game.center; }
    CGRect b=gWin?gWin.bounds:UIScreen.mainScreen.bounds;
    self.frame=b;
    CGFloat W=b.size.width,H=b.size.height,S=50;
    CGPoint c=self.fab.center;
    if(c.x<S||c.y<S||c.x>W-4||c.y>H-4) self.fab.frame=CGRectMake(W-S-16,H*0.42f,S,S);
    else { c.x=fminf(W-S*0.5f-4,fmaxf(S*0.5f+4,c.x)); c.y=fminf(H-S*0.5f-4,fmaxf(S*0.5f+4,c.y)); self.fab.center=c; }
    CGFloat pw=fminf(W*0.92f,640), ph=fminf(H*0.88f,360);
    if(W<H){ pw=fminf(W-12,360); ph=fminf(H*0.75f,480); }
    self.panel.bounds=CGRectMake(0,0,pw,ph);
    if(self.panel.center.x<30||self.panel.center.y<30) self.panel.center=CGPointMake(W*0.5f,H*0.5f);
    CGFloat sw=(W<H)?110:150;
    self.side.frame=CGRectMake(0,0,sw,ph);
    self.scroll.frame=CGRectMake(sw,0,pw-sw,ph);
    self.langBtn.frame=CGRectMake(8,ph-40,sw-16,30);
    if(self.secureTF) self.secureTF.frame=self.superview?self.superview.bounds:b;
}

- (UIView*)secureCanvas{
    if(!self.secureTF)return nil; [self.secureTF layoutIfNeeded];
    for(UIView*s in self.secureTF.subviews){
        NSString*c=NSStringFromClass(s.class);
        if([c containsString:@"Canvas"]||[c containsString:@"TextLayout"]||[c containsString:@"Field"]) return s;
    }
    return self.secureTF.subviews.lastObject;
}

- (void)applyHide{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL sec=NSSelectorFromString(@"_setSecure:");
    if(gWin&&[gWin respondsToSelector:sec]) ((void(*)(id,SEL,BOOL))objc_msgSend)(gWin,sec,gHideRec);
#pragma clang diagnostic pop
    UIView*root=gWin.rootViewController.view;
    if(!gHideRec){
        [self.secureTF removeFromSuperview];
        if(self.superview!=root){ [self removeFromSuperview]; self.frame=root.bounds; [root addSubview:self]; }
        return;
    }
    if(!self.secureTF){
        self.secureTF=[[UITextField alloc]initWithFrame:root.bounds];
        self.secureTF.secureTextEntry=YES; self.secureTF.backgroundColor=UIColor.clearColor;
        self.secureTF.userInteractionEnabled=YES;
        self.secureTF.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    }
    self.secureTF.frame=root.bounds;
    if(self.secureTF.superview!=root)[root addSubview:self.secureTF];
    UIView*canvas=[self secureCanvas];
    if(canvas){
        canvas.userInteractionEnabled=YES; canvas.backgroundColor=UIColor.clearColor;
        if(self.superview!=canvas){
            [self removeFromSuperview]; self.frame=canvas.bounds;
            self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            [canvas addSubview:self];
        }
    }
}

- (void)addCard:(NSString*)title desc:(NSString*)desc y:(CGFloat)y tag:(int)tag on:(BOOL)on slider:(BOOL)sl{
    CGFloat w=MAX(200,self.scroll.bounds.size.width-24);
    UIView*c=[[UIView alloc]initWithFrame:CGRectMake(12,y,w,sl?88:64)];
    c.backgroundColor=self.cardBG; c.layer.cornerRadius=14;
    c.layer.borderWidth=1; c.layer.borderColor=[self.neon colorWithAlphaComponent:0.22].CGColor;
    c.tag=tag; c.userInteractionEnabled=YES;
    UILabel*t=[[UILabel alloc]initWithFrame:CGRectMake(16,10,w-90,20)];
    t.text=title; t.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; t.textColor=UIColor.whiteColor;
    t.userInteractionEnabled=NO; [c addSubview:t];
    UILabel*d=[[UILabel alloc]initWithFrame:CGRectMake(16,32,w-90,18)];
    d.text=desc; d.font=[UIFont systemFontOfSize:11]; d.textColor=[UIColor colorWithWhite:0.55 alpha:1];
    d.userInteractionEnabled=NO; [c addSubview:d];
    UISwitch*sw=[[UISwitch alloc]initWithFrame:CGRectZero];
    sw.on=on; sw.onTintColor=self.neon; sw.center=CGPointMake(w-42,32);
    [sw addTarget:self action:@selector(onSw:) forControlEvents:UIControlEventValueChanged];
    [c addSubview:sw];
    if(sl){
        UISlider*s=[[UISlider alloc]initWithFrame:CGRectMake(16,56,w-100,24)];
        s.minimumValue=1; s.maximumValue=30; s.value=gFov; s.tag=2;
        s.minimumTrackTintColor=self.neon;
        [s addTarget:self action:@selector(onFov:) forControlEvents:UIControlEventValueChanged];
        [c addSubview:s];
        UILabel*lv=[[UILabel alloc]initWithFrame:CGRectMake(w-80,56,68,24)]; lv.tag=3;
        lv.textAlignment=NSTextAlignmentRight; lv.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        lv.textColor=[UIColor colorWithWhite:0.7 alpha:1];
        lv.text=[NSString stringWithFormat:@"%.0f  |  1—30",gFov]; [c addSubview:lv];
    }
    [self.scroll addSubview:c];
}

- (void)rebuild{
    for(UIView*v in self.scroll.subviews.copy)[v removeFromSuperview];
    NSArray*ru=@[@"Прицел",@"Визуалы",@"Разное",@"Конфиг"];
    NSArray*en=@[@"Aim",@"Visuals",@"Misc",@"Config"];
    for(int i=0;i<4;i++){
        UIButton*b=(UIButton*)[self.side viewWithTag:100+i];
        BOOL on=gTab==i;
        [b setTitle:(gLang==0?ru[i]:en[i]) forState:UIControlStateNormal];
        [b setTitleColor:on?UIColor.whiteColor:[UIColor colorWithWhite:0.5 alpha:1] forState:UIControlStateNormal];
        b.backgroundColor=on?[self.neon colorWithAlphaComponent:0.28]:UIColor.clearColor;
    }
    [self.langBtn setTitle:(gLang==0?@"  🌐  Русский":@"  🌐  English") forState:UIControlStateNormal];
    CGFloat y=14;
    if(gTab==0){
        [self addCard:T(@"Аимбот",@"Aim bot") desc:T(@"Автоприцел по врагам",@"Automatically aims at enemies") y:y tag:10 on:gAim slider:NO]; y+=76;
        [self addCard:T(@"Круг FOV",@"FOV Circle") desc:T(@"Показать зону прицела",@"Shows the aim range circle") y:y tag:11 on:gFovDraw slider:YES]; y+=100;
        [self addCard:T(@"Сайлент",@"Silent") desc:T(@"Скрытый аим",@"Hides your aim from others") y:y tag:12 on:gSilent slider:NO]; y+=76;
        [self addCard:T(@"Без отдачи",@"No Recoil") desc:T(@"Убрать отдачу",@"Remove weapon recoil") y:y tag:13 on:gNoRecoil slider:NO]; y+=76;
    } else if(gTab==1){
        [self addCard:@"ESP" desc:T(@"Показать игроков",@"Show players") y:y tag:20 on:gEsp slider:NO]; y+=76;
        [self addCard:T(@"Бокс",@"Box") desc:@"" y:y tag:21 on:gBox slider:NO]; y+=76;
        [self addCard:T(@"Имя",@"Name") desc:@"" y:y tag:22 on:gName slider:NO]; y+=76;
        [self addCard:T(@"ХП",@"HP") desc:@"" y:y tag:23 on:gHP slider:NO]; y+=76;
        [self addCard:T(@"Дистанция",@"Distance") desc:@"" y:y tag:24 on:gDist slider:NO]; y+=76;
        [self addCard:T(@"Линии",@"Snaplines") desc:@"" y:y tag:25 on:gSnap slider:NO]; y+=76;
        [self addCard:T(@"Тимчек",@"Team check") desc:@"" y:y tag:26 on:gTeam slider:NO]; y+=76;
    } else if(gTab==2){
        [self addCard:T(@"Скрыть запись",@"Hide Recording") desc:T(@"Скрин и запись экрана",@"Screenshot & screen recording") y:y tag:30 on:gHideRec slider:NO]; y+=76;
    } else {
        UILabel*cur=[[UILabel alloc]initWithFrame:CGRectMake(16,y,300,18)];
        cur.text=[NSString stringWithFormat:@"%@: %@",T(@"Конфиг",@"Config"),gCfgName];
        cur.textColor=[UIColor colorWithWhite:0.6 alpha:1]; cur.font=[UIFont systemFontOfSize:13];
        [self.scroll addSubview:cur]; y+=28;
        UIButton*save=[UIButton buttonWithType:UIButtonTypeSystem];
        save.frame=CGRectMake(16,y,140,40);
        [save setTitle:T(@"Сохранить",@"Save") forState:UIControlStateNormal];
        [save setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        save.backgroundColor=[self.neon colorWithAlphaComponent:0.45]; save.layer.cornerRadius=12;
        [save addTarget:self action:@selector(saveCfg) forControlEvents:UIControlEventTouchUpInside];
        [self.scroll addSubview:save]; y+=52;
    }
    self.scroll.contentSize=CGSizeMake(self.scroll.bounds.size.width,y+20);
}

- (void)onSw:(UISwitch*)s{
    int t=(int)s.superview.tag; BOOL v=s.on;
    switch(t){
        case 10:gAim=v;break; case 11:gFovDraw=v;break; case 12:gSilent=v;break; case 13:gNoRecoil=v;break;
        case 20:gEsp=v;break; case 21:gBox=v;break; case 22:gName=v;break; case 23:gHP=v;break;
        case 24:gDist=v;break; case 25:gSnap=v;break; case 26:gTeam=v;break;
        case 30:gHideRec=v; [self applyHide]; break;
    }
    SaveCfg();
}
- (void)onFov:(UISlider*)sl{
    gFov=sl.value;
    UILabel*l=[sl.superview viewWithTag:3];
    l.text=[NSString stringWithFormat:@"%.0f  |  1—30",gFov];
    SaveCfg();
}
- (void)tab:(UIButton*)b{ gTab=(int)b.tag-100; [self rebuild]; }
- (void)togLang{ gLang=gLang?0:1; [self rebuild]; SaveCfg(); }
- (void)saveCfg{ SaveCfg(); }
- (void)fabTap{ gMenu=!gMenu; self.panel.hidden=!gMenu; if(gMenu){[self relayout];[self rebuild];} }
- (void)fabPan:(UIPanGestureRecognizer*)g{
    CGPoint t=[g translationInView:self]; CGPoint c=self.fab.center; c.x+=t.x; c.y+=t.y;
    CGFloat h=25,W=self.bounds.size.width,H=self.bounds.size.height;
    c.x=fmaxf(h,fminf(W-h,c.x)); c.y=fmaxf(h,fminf(H-h,c.y));
    self.fab.center=c; [g setTranslation:CGPointZero inView:self];
}
- (void)panPanel:(UIPanGestureRecognizer*)g{
    CGPoint t=[g translationInView:self]; CGPoint c=self.panel.center; c.x+=t.x; c.y+=t.y;
    self.panel.center=c; [g setTranslation:CGPointZero inView:self];
}
- (void)drawRect:(CGRect)rect{
    if(!gReady)return;
    GameTick();
    CGContextRef ctx=UIGraphicsGetCurrentContext(); if(!ctx)return;
    CGFloat W=rect.size.width,H=rect.size.height;
    if(gAim&&gFovDraw){
        CGFloat r=18.f+gFov*3.2f;
        CGContextSetStrokeColorWithColor(ctx,[self.neon colorWithAlphaComponent:0.45].CGColor);
        CGContextSetLineWidth(ctx,1.3);
        CGContextStrokeEllipseInRect(ctx,CGRectMake(W*0.5f-r,H*0.5f-r,r*2,r*2));
    }
}
- (UIView*)hitTest:(CGPoint)p withEvent:(UIEvent*)e{
    if(!gReady)return nil;
    if(gMenu&&!self.panel.hidden){
        CGPoint pp=[self convertPoint:p toView:self.panel];
        if([self.panel pointInside:pp withEvent:e]) return [self.panel hitTest:pp withEvent:e]?:self.panel;
    }
    CGPoint fp=[self convertPoint:p toView:self.fab];
    if([self.fab pointInside:fp withEvent:e]) return self.fab;
    return nil;
}
- (void)boot{
    gReady=YES; LoadCfg(); [self relayout]; [self applyHide];
    self.link=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    self.link.preferredFramesPerSecond=30;
    [self.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(onOrient)
                                                 name:UIDeviceOrientationDidChangeNotification object:nil];
    [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
}
- (void)onOrient{ dispatch_async(dispatch_get_main_queue(),^{ [self relayout]; if(gMenu)[self rebuild]; }); }
- (void)tick:(CADisplayLink*)l{
    UIWindow*game=GameWin();
    if(gWin&&game){
        BOOL moved=!CGAffineTransformEqualToTransform(gWin.transform,game.transform)
            ||fabs(gWin.bounds.size.width-game.bounds.size.width)>1
            ||fabs(gWin.bounds.size.height-game.bounds.size.height)>1;
        if(moved)[self relayout];
    }
    [self setNeedsDisplay];
}
@end

static void Start(void){
    if(gWin)return;
    dispatch_async(dispatch_get_main_queue(),^{
        UIWindow*game=GameWin();
        CGRect b=game?game.bounds:UIScreen.mainScreen.bounds;
        gWin=[[ACW alloc]initWithFrame:b];
        if(game){ gWin.transform=game.transform; gWin.bounds=game.bounds; gWin.center=game.center; }
        gWin.windowLevel=UIWindowLevelAlert+50;
        gWin.backgroundColor=UIColor.clearColor; gWin.userInteractionEnabled=YES;
        ACVC*r=[ACVC new]; r.view.backgroundColor=UIColor.clearColor; r.view.userInteractionEnabled=YES;
        gWin.rootViewController=r;
        gHud=[[ACH alloc]initWithFrame:gWin.bounds];
        [r.view addSubview:gHud];
        UIWindow*prev=UIApplication.sharedApplication.keyWindow;
        gWin.hidden=NO; [gWin makeKeyAndVisible];
        if(prev&&prev!=gWin)[prev makeKeyWindow];
        [gHud boot];
    });
}

__attribute__((constructor))
static void onLoad(void){
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ Start(); });
}
