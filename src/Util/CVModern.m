// CVModern.m - see CVModern.h. Shared by all of samcejko's iOS 6 apps (only the prefix differs).
//
// Compiled twice: with the iOS 9.3 SDK for the armv7 build (deployment target iOS 6.0) and with the iOS 16.5 SDK
// for the arm64 build (deployment target iOS 14.0). APIs newer than a SDK are behind __IPHONE_OS_VERSION_MAX_ALLOWED,
// APIs newer than the running iOS behind version checks; so this file opts out of the availability errors of the
// app's common header (which it does not import) and of the deprecation warnings of the iOS 6 era APIs it bridges.
#import "CVModern.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunknown-pragmas"

#pragma mark - Versions

static NSInteger CVMajorVersion(void)
{
    static NSInteger major = 0;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        major = [[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."][0] integerValue];
        if (major < 1) major = 6;
    });
    return major;
}

BOOL CVModernIOS(void) { return CVMajorVersion() >= 7; }
static BOOL CVAtLeast(NSInteger major) { return CVMajorVersion() >= major; }

#pragma mark - Safe areas

UIEdgeInsets CVSafeAreaInsets(UIView *view)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (view && CVAtLeast(11)) return view.safeAreaInsets;
#endif
    return UIEdgeInsetsZero;
}

UIEdgeInsets CVScreenSafeAreaInsets(void)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (CVAtLeast(11)) {
        UIApplication *app = [UIApplication sharedApplication];
        UIWindow *window = app.keyWindow ?: app.windows.firstObject;
        if (window) return window.safeAreaInsets;
    }
#endif
    return UIEdgeInsetsZero;
}

UIStatusBarStyle CVModernStatusBarStyle(UIStatusBarStyle ios6Style)
{
    // 1 is UIStatusBarStyleLightContent from iOS 7 on (UIStatusBarStyleBlackTranslucent of the iOS 6 headers)
    return CVModernIOS() ? (UIStatusBarStyle)1 : ios6Style;
}

CGFloat CVModernTopInset(UIView *view, CGFloat ios6Value)
{
    if (!CVModernIOS()) return ios6Value;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (CVAtLeast(11) && view.window) return view.safeAreaInsets.top;
#endif
    if ([UIApplication sharedApplication].statusBarHidden) return 0;
    CGRect frame = [UIApplication sharedApplication].statusBarFrame;
    return MIN(frame.size.width, frame.size.height);
}

CGFloat CVModernGroupedCellMargins(CGFloat ios6Margins)
{
    if (!CVModernIOS()) return ios6Margins;
    return CVAtLeast(13) ? 40 : 0;
}

#pragma mark - The iOS 6 artwork, drawn in code

static UIColor *CVRGB(NSInteger r, NSInteger g, NSInteger b)
{
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

// The colors of one glossy surface: a gradient from c1 to c2 in the upper half, a hard edge, c3 to c4 below.
typedef struct {
    NSInteger c1, c2, c3, c4;   // 0xRRGGBB
    NSInteger line;             // the border (bars: the bottom line; buttons: the outline)
    CGFloat highlight;          // alpha of the white line along the top edge
} CVGloss;

static UIColor *CVHex(NSInteger rgb) { return CVRGB((rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff); }

static void CVDrawGloss(CGContextRef ctx, CGRect rect, CVGloss g)
{
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[4] = { 0.0, 0.5, 0.5, 1.0 };
    NSArray *colors = @[ (id)CVHex(g.c1).CGColor, (id)CVHex(g.c2).CGColor, (id)CVHex(g.c3).CGColor, (id)CVHex(g.c4).CGColor ];
    CGGradientRef gradient = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colors, locations);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect)),
                                CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect)), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(cs);
}

// Bars (navigation bar, toolbar, search bar background): the iOS 6 blue, or the black of UIBarStyleBlack
static CVGloss CVBarGloss(BOOL black)
{
    CVGloss blue = { 0xb0bccd, 0x889bb3, 0x8195af, 0x6d84a2, 0x2d3642, 0.35 };
    CVGloss dark = { 0x4d4d4d, 0x2e2e2e, 0x262626, 0x141414, 0x000000, 0.18 };
    return black ? dark : blue;
}

// A bar background. `above` is the height of the status bar the bar extends under on iOS 7 and newer (the iOS 6
// status bar took the tint of the bar below it, so that part is drawn as a lighter gradient of the same color).
static UIImage *CVBarImage(BOOL black, CGFloat above, CGFloat height)
{
    CVGloss g = CVBarGloss(black);
    CGSize size = CGSizeMake(2, above + height);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (above > 0) {
        CVGloss status = g;
        status.c2 = status.c1;
        status.c3 = status.c1;
        status.c4 = g.c2;
        CVDrawGloss(ctx, CGRectMake(0, 0, size.width, above), status);
    }
    CVDrawGloss(ctx, CGRectMake(0, above, size.width, height), g);
    [[UIColor colorWithWhite:1.0 alpha:g.highlight] setFill];
    UIRectFillUsingBlendMode(CGRectMake(0, above, size.width, 1), kCGBlendModeNormal);
    [CVHex(g.line) setFill];
    UIRectFill(CGRectMake(0, size.height - 1, size.width, 1));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(1, 0, 1, 0) resizingMode:UIImageResizingModeStretch];
}

// Bordered bar buttons: normal, pressed and the blue "Done" style, on the blue or the black bar
static CVGloss CVButtonGloss(BOOL black, BOOL highlighted, BOOL done)
{
    if (done) {
        CVGloss d = { 0x6aa0e6, 0x3c7cd8, 0x3374d4, 0x2563c6, 0x1d478a, 0.4 };
        CVGloss dh = { 0x4e7fc4, 0x2a62b8, 0x235bb4, 0x184ea6, 0x15397a, 0.2 };
        return highlighted ? dh : d;
    }
    if (black) {
        CVGloss b = { 0x6e6e6e, 0x4b4b4b, 0x434343, 0x333333, 0x0b0b0b, 0.25 };
        CVGloss bh = { 0x4a4a4a, 0x303030, 0x2a2a2a, 0x1e1e1e, 0x050505, 0.1 };
        return highlighted ? bh : b;
    }
    CVGloss n = { 0x8fa4c4, 0x748cb1, 0x6d86ad, 0x5f79a3, 0x3b4b62, 0.4 };
    CVGloss nh = { 0x62789a, 0x4e6488, 0x485f84, 0x3f567c, 0x2a3648, 0.2 };
    return highlighted ? nh : n;
}

// The outline of a bar button (30 pt tall): a rounded rectangle, or the iOS 6 back button with its pointed left end
static UIBezierPath *CVButtonPath(CGRect r, BOOL back)
{
    CGFloat radius = 5.0;
    if (!back) return [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
    CGFloat tip = 12.0, midY = CGRectGetMidY(r);
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(CGRectGetMinX(r) + tip, CGRectGetMinY(r))];
    [p addLineToPoint:CGPointMake(CGRectGetMaxX(r) - radius, CGRectGetMinY(r))];
    [p addArcWithCenter:CGPointMake(CGRectGetMaxX(r) - radius, CGRectGetMinY(r) + radius) radius:radius startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [p addLineToPoint:CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r) - radius)];
    [p addArcWithCenter:CGPointMake(CGRectGetMaxX(r) - radius, CGRectGetMaxY(r) - radius) radius:radius startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [p addLineToPoint:CGPointMake(CGRectGetMinX(r) + tip, CGRectGetMaxY(r))];
    [p addLineToPoint:CGPointMake(CGRectGetMinX(r) + 1.5, midY + 1.5)];
    [p addQuadCurveToPoint:CGPointMake(CGRectGetMinX(r) + 1.5, midY - 1.5) controlPoint:CGPointMake(CGRectGetMinX(r), midY)];
    [p closePath];
    return p;
}

static UIImage *CVButtonImage(BOOL black, BOOL highlighted, BOOL done, BOOL back)
{
    CVGloss g = CVButtonGloss(black, highlighted, done);
    CGSize size = CGSizeMake(back ? 28 : 14, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect inner = CGRectInset(CGRectMake(0, 0, size.width, size.height), 0.5, 0.5);
    UIBezierPath *path = CVButtonPath(inner, back);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path.CGPath);
    CGContextClip(ctx);
    CVDrawGloss(ctx, CGRectMake(0, 0, size.width, size.height), g);
    [[UIColor colorWithWhite:1.0 alpha:g.highlight] setFill];
    UIRectFillUsingBlendMode(CGRectMake(0, 1, size.width, 1), kCGBlendModeNormal);
    CGContextRestoreGState(ctx);
    [CVHex(g.line) setStroke];
    path.lineWidth = 1.0;
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIEdgeInsets caps = back ? UIEdgeInsetsMake(7, 15, 7, 6) : UIEdgeInsetsMake(7, 6, 7, 6);
    return [image resizableImageWithCapInsets:caps resizingMode:UIImageResizingModeStretch];
}

// A fully transparent image (hides the iOS 7 back chevron: the pointed button background draws the arrow)
static UIImage *CVClearImage(CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// The white rounded text field of the iOS 6 search bar
static UIImage *CVSearchFieldImage(void)
{
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(CGRectMake(0, 0, size.width, size.height), 0.5, 0.5) cornerRadius:14.5];
    [[UIColor whiteColor] setFill];
    [path fill];
    [[UIColor colorWithWhite:0.0 alpha:0.35] setStroke];
    path.lineWidth = 1.0;
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(14, 14, 14, 14) resizingMode:UIImageResizingModeStretch];
}

// The black iOS 6 tab bar, and the darker rounded area behind its selected item
static UIImage *CVTabBarImage(void)
{
    CVGloss g = { 0x484848, 0x2a2a2a, 0x202020, 0x0a0a0a, 0x000000, 0.2 };
    CGSize size = CGSizeMake(2, 49);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    CVDrawGloss(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, size.width, size.height), g);
    [[UIColor colorWithWhite:1.0 alpha:g.highlight] setFill];
    UIRectFillUsingBlendMode(CGRectMake(0, 0, size.width, 1), kCGBlendModeNormal);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(1, 0, 1, 0) resizingMode:UIImageResizingModeStretch];
}

static UIImage *CVTabSelectionImage(void)
{
    CGSize size = CGSizeMake(64, 49);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 3, size.width - 4, size.height - 6) cornerRadius:5];
    [[UIColor colorWithWhite:1.0 alpha:0.14] setFill];
    [path fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10) resizingMode:UIImageResizingModeStretch];
}

// Segments of a plain segmented control: light gray or dark glossy for black theme
static UIImage *CVSegmentImage(BOOL selected, BOOL black)
{
    CVGloss normalLight = { 0xfbfbfb, 0xe6e6e6, 0xdcdcdc, 0xc9c9c9, 0x8e8e8e, 0.0 };
    CVGloss selLight = { 0x9c9c9c, 0x7a7a7a, 0x717171, 0x5e5e5e, 0x4a4a4a, 0.15 };
    CVGloss normalDark = { 0x3e3e42, 0x2b2b2e, 0x242427, 0x161618, 0x111113, 0.12 };
    CVGloss selDark = { 0x18181b, 0x121214, 0x0e0e10, 0x080809, 0x000000, 0.0 };

    CVGloss g;
    if (black) {
        g = selected ? selDark : normalDark;
    } else {
        g = selected ? selLight : normalLight;
    }
    CGSize size = CGSizeMake(14, 32);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect inner = CGRectInset(CGRectMake(0, 0, size.width, size.height), 0.5, 0.5);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:inner cornerRadius:5];
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path.CGPath);
    CGContextClip(ctx);
    CVDrawGloss(ctx, CGRectMake(0, 0, size.width, size.height), g);
    if (g.highlight > 0) {
        [[UIColor colorWithWhite:1.0 alpha:g.highlight] setFill];
        UIRectFillUsingBlendMode(CGRectMake(0, 1, size.width, 1), kCGBlendModeNormal);
    }
    CGContextRestoreGState(ctx);
    [CVHex(g.line) setStroke];
    path.lineWidth = 1.0;
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(7, 6, 7, 6) resizingMode:UIImageResizingModeStretch];
}

static UIImage *CVSegmentDividerImage(BOOL black)
{
    CGSize size = CGSizeMake(1, 32);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [CVHex(black ? 0x18181b : 0x8e8e8e) setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Text styles

// White, bold, with the dark shadow above the glyphs that iOS 6 gave bar titles and bar buttons
static NSDictionary *CVEmbossedTextAttributes(CGFloat fontSize)
{
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    shadow.shadowOffset = CGSizeMake(0, -1);
    return @{ NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize],
              NSForegroundColorAttributeName: [UIColor whiteColor],
              NSShadowAttributeName: shadow };
}

static NSDictionary *CVEngravedTextAttributes(CGFloat fontSize, UIColor *color)
{
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    shadow.shadowOffset = CGSizeMake(0, 1);
    return @{ NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize],
              NSForegroundColorAttributeName: color,
              NSShadowAttributeName: shadow };
}

#pragma mark - Bars

// The height of the status bar the navigation bar reaches under in portrait (0 when it is hidden)
static CGFloat CVStatusBarHeight(void)
{
    CGRect frame = [UIApplication sharedApplication].statusBarFrame;
    CGFloat h = MIN(frame.size.width, frame.size.height);
    if (h <= 0) h = 20;
    return h;
}

static BOOL CVIsBlack(UIBarStyle style) { return style == UIBarStyleBlack; }

// Legacy customization (iOS 7-12; also what iOS 13 and newer fall back to where no appearance object is set).
// Whatever the look, the bar is dark: UIBarStyleBlack makes the status bar's text light and the title white.
static void CVApplyLegacyNavigationBar(UINavigationBar *bar, BOOL black)
{
    UIImage *tall = CVBarImage(black, CVStatusBarHeight(), 44);
    UIImage *compact = CVBarImage(black, 0, 32);
    [bar setBackgroundImage:tall forBarMetrics:UIBarMetricsDefault];
    [bar setBackgroundImage:compact forBarMetrics:(UIBarMetrics)1];   // UIBarMetricsCompact (landscape iPhone)
    [bar setShadowImage:CVClearImage(CGSizeMake(1, 1))];
    [bar setTitleTextAttributes:CVEmbossedTextAttributes(20)];
    [bar setTintColor:[UIColor whiteColor]];
    [bar setBarStyle:UIBarStyleBlack];
    if ([bar respondsToSelector:@selector(setBackIndicatorImage:)]) {
        [bar setBackIndicatorImage:CVClearImage(CGSizeMake(1, 20))];
        [bar setBackIndicatorTransitionMaskImage:CVClearImage(CGSizeMake(1, 20))];
    }
}

static void CVApplyLegacyBarButtons(UIBarButtonItem *proxy, BOOL black)
{
    for (int metrics = 0; metrics < 2; metrics++) {
        [proxy setBackgroundImage:CVButtonImage(black, NO, NO, NO) forState:UIControlStateNormal barMetrics:(UIBarMetrics)metrics];
        [proxy setBackgroundImage:CVButtonImage(black, YES, NO, NO) forState:UIControlStateHighlighted barMetrics:(UIBarMetrics)metrics];
        [proxy setBackgroundImage:CVButtonImage(black, NO, YES, NO) forState:UIControlStateNormal style:UIBarButtonItemStyleDone barMetrics:(UIBarMetrics)metrics];
        [proxy setBackgroundImage:CVButtonImage(black, YES, YES, NO) forState:UIControlStateHighlighted style:UIBarButtonItemStyleDone barMetrics:(UIBarMetrics)metrics];
        [proxy setBackButtonBackgroundImage:CVButtonImage(black, NO, NO, YES) forState:UIControlStateNormal barMetrics:(UIBarMetrics)metrics];
        [proxy setBackButtonBackgroundImage:CVButtonImage(black, YES, NO, YES) forState:UIControlStateHighlighted barMetrics:(UIBarMetrics)metrics];
        [proxy setBackButtonTitlePositionAdjustment:UIOffsetMake(6, 0) forBarMetrics:(UIBarMetrics)metrics];
    }
    [proxy setTitleTextAttributes:CVEmbossedTextAttributes(12) forState:UIControlStateNormal];
    [proxy setTitleTextAttributes:CVEmbossedTextAttributes(12) forState:UIControlStateHighlighted];
}

static void CVApplyLegacyToolbar(UIToolbar *bar, BOOL black)
{
    [bar setBackgroundImage:CVBarImage(black, 0, 44) forToolbarPosition:(UIBarPosition)0 barMetrics:UIBarMetricsDefault];
    [bar setBackgroundImage:CVBarImage(black, 0, 32) forToolbarPosition:(UIBarPosition)0 barMetrics:(UIBarMetrics)1];
    [bar setShadowImage:CVClearImage(CGSizeMake(1, 1)) forToolbarPosition:(UIBarPosition)0];
    [bar setTintColor:[UIColor whiteColor]];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
// iOS 13 and newer: the appearance objects (without them iOS 15 draws the bars transparent at the scroll edge)
static UIBarButtonItemAppearance *CVButtonAppearance(BOOL black, BOOL done, BOOL back)
{
    UIBarButtonItemAppearance *a = [[UIBarButtonItemAppearance alloc] initWithStyle:done ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain];
    NSDictionary *text = CVEmbossedTextAttributes(12);
    a.normal.backgroundImage = CVButtonImage(black, NO, done, back);
    a.normal.titleTextAttributes = text;
    a.highlighted.backgroundImage = CVButtonImage(black, YES, done, back);
    a.highlighted.titleTextAttributes = text;
    a.disabled.backgroundImage = a.normal.backgroundImage;
    a.disabled.titleTextAttributes = @{ NSFontAttributeName: [UIFont boldSystemFontOfSize:12], NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.5] };
    if (back) {
        a.normal.titlePositionAdjustment = UIOffsetMake(6, 0);
        a.highlighted.titlePositionAdjustment = UIOffsetMake(6, 0);
        a.disabled.titlePositionAdjustment = UIOffsetMake(6, 0);
    }
    return a;
}

static UINavigationBarAppearance *CVNavigationBarAppearance(BOOL black, BOOL compact)
{
    UINavigationBarAppearance *a = [[UINavigationBarAppearance alloc] init];
    [a configureWithOpaqueBackground];
    a.backgroundImage = compact ? CVBarImage(black, 0, 32) : CVBarImage(black, CVStatusBarHeight(), 44);
    a.backgroundImageContentMode = UIViewContentModeScaleToFill;
    a.shadowColor = nil;
    a.shadowImage = nil;
    a.titleTextAttributes = CVEmbossedTextAttributes(compact ? 17 : 20);
    a.largeTitleTextAttributes = CVEmbossedTextAttributes(34);
    a.buttonAppearance = CVButtonAppearance(black, NO, NO);
    a.doneButtonAppearance = CVButtonAppearance(black, YES, NO);
    a.backButtonAppearance = CVButtonAppearance(black, NO, YES);
    [a setBackIndicatorImage:CVClearImage(CGSizeMake(1, 20)) transitionMaskImage:CVClearImage(CGSizeMake(1, 20))];
    return a;
}

static void CVSetNavigationBarAppearances(UINavigationBar *bar, UINavigationBarAppearance *standard, UINavigationBarAppearance *compact)
{
    [bar setStandardAppearance:standard];
    [bar setScrollEdgeAppearance:standard];
    [bar setCompactAppearance:compact];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 150000
    if (CVAtLeast(15)) [bar setCompactScrollEdgeAppearance:compact];
#endif
}

static void CVApplyNavigationBarAppearance(UINavigationBar *bar, BOOL black)
{
    CVSetNavigationBarAppearances(bar, CVNavigationBarAppearance(black, NO), CVNavigationBarAppearance(black, YES));
    [bar setTintColor:[UIColor whiteColor]];
    [bar setBarStyle:UIBarStyleBlack];
}

static UIToolbarAppearance *CVToolbarAppearance(BOOL black, BOOL compact)
{
    UIToolbarAppearance *a = [[UIToolbarAppearance alloc] init];
    [a configureWithOpaqueBackground];
    a.backgroundImage = CVBarImage(black, 0, compact ? 32 : 44);
    a.backgroundImageContentMode = UIViewContentModeScaleToFill;
    a.shadowColor = nil;
    a.shadowImage = nil;
    return a;
}

static void CVApplyToolbarAppearance(UIToolbar *bar, BOOL black)
{
    UIToolbarAppearance *standard = CVToolbarAppearance(black, NO);
    UIToolbarAppearance *compact = CVToolbarAppearance(black, YES);
    [bar setStandardAppearance:standard];
    [bar setCompactAppearance:compact];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 150000
    if (CVAtLeast(15)) {
        [bar setScrollEdgeAppearance:standard];
        [bar setCompactScrollEdgeAppearance:compact];
    }
#endif
    [bar setTintColor:[UIColor whiteColor]];
}

static void CVSetTabBarAppearance(UITabBar *bar, UITabBarAppearance *a)
{
    [bar setStandardAppearance:a];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 150000
    if (CVAtLeast(15)) [bar setScrollEdgeAppearance:a];
#endif
}

static void CVApplyTabBarAppearance(UITabBar *bar)
{
    UITabBarAppearance *a = [[UITabBarAppearance alloc] init];
    [a configureWithOpaqueBackground];
    a.backgroundImage = CVTabBarImage();
    a.shadowColor = nil;
    a.shadowImage = nil;
    a.selectionIndicatorImage = CVTabSelectionImage();
    UIColor *selected = CVRGB(235, 45, 55), *normal = CVRGB(146, 146, 146);
    for (UITabBarItemAppearance *item in @[ a.stackedLayoutAppearance, a.inlineLayoutAppearance, a.compactInlineLayoutAppearance ]) {
        item.selected.iconColor = selected;
        item.selected.titleTextAttributes = @{ NSForegroundColorAttributeName: selected, NSFontAttributeName: [UIFont boldSystemFontOfSize:10] };
        item.normal.iconColor = normal;
        item.normal.titleTextAttributes = @{ NSForegroundColorAttributeName: normal, NSFontAttributeName: [UIFont boldSystemFontOfSize:10] };
    }
    CVSetTabBarAppearance(bar, a);
    [bar setTintColor:selected];
}
#endif

void CVModernApplyNavigationBarBackground(UINavigationBar *bar, UIImage *image, NSDictionary *titleAttributes,
                                             UIImage *buttonImage, UIImage *buttonImageHighlighted, NSDictionary *buttonTitleAttributes)
{
    if (!bar || !image || !CVModernIOS()) return;
    bar.translucent = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) {
        UINavigationBarAppearance *a = [[UINavigationBarAppearance alloc] init];
        [a configureWithOpaqueBackground];
        a.backgroundImage = image;
        a.backgroundImageContentMode = UIViewContentModeScaleToFill;
        a.shadowColor = nil;
        a.shadowImage = nil;
        if (titleAttributes) a.titleTextAttributes = titleAttributes;
        if (buttonImage || buttonTitleAttributes) {
            for (UIBarButtonItemAppearance *b in @[ a.buttonAppearance, a.doneButtonAppearance, a.backButtonAppearance ]) {
                if (buttonImage) {
                    b.normal.backgroundImage = buttonImage;
                    b.highlighted.backgroundImage = buttonImageHighlighted ?: buttonImage;
                    b.disabled.backgroundImage = buttonImage;
                }
                if (buttonTitleAttributes) {
                    b.normal.titleTextAttributes = buttonTitleAttributes;
                    b.highlighted.titleTextAttributes = buttonTitleAttributes;
                }
            }
        }
        CVSetNavigationBarAppearances(bar, a, a);
        return;
    }
#endif
    [bar setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
    [bar setBackgroundImage:image forBarMetrics:(UIBarMetrics)1];
    [bar setShadowImage:CVClearImage(CGSizeMake(1, 1))];
    if (titleAttributes) [bar setTitleTextAttributes:titleAttributes];
    // (the legacy button images come from the app's own UIBarButtonItem appearance; nothing more to do here)
}

UITextField *CVModernSearchBarTextField(UISearchBar *bar)
{
    if (!bar) return nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) return bar.searchTextField;
#endif
    NSMutableArray *queue = [NSMutableArray arrayWithObject:bar];
    while (queue.count) {
        UIView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([v isKindOfClass:[UITextField class]]) return (UITextField *)v;
        [queue addObjectsFromArray:v.subviews];
    }
    return nil;
}

void CVModernApplyTabBarBackground(UITabBar *bar, UIImage *image)
{
    if (!bar || !image || !CVModernIOS()) return;
    bar.translucent = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) {
        UITabBarAppearance *a = [[UITabBarAppearance alloc] init];
        [a configureWithOpaqueBackground];
        a.backgroundImage = image;
        a.shadowColor = nil;
        a.shadowImage = nil;
        CVSetTabBarAppearance(bar, a);
        return;
    }
#endif
    [bar setBackgroundImage:image];
    [bar setShadowImage:CVClearImage(CGSizeMake(1, 1))];
}

void CVModernKeepScrollViewInsets(UIScrollView *scrollView)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (scrollView && CVAtLeast(11)) scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
#endif
}

void CVModernDisableSwipeBack(UINavigationController *nav)
{
    if (nav && [nav respondsToSelector:@selector(interactivePopGestureRecognizer)]) nav.interactivePopGestureRecognizer.enabled = NO;
}

void CVModernStatusBarChanged(UIViewController *vc)
{
    if (vc && [vc respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) [vc setNeedsStatusBarAppearanceUpdate];
}

void CVModernStyleNavigationBar(UINavigationBar *bar)
{
    if (!bar || !CVModernIOS()) return;
    BOOL black = CVIsBlack(bar.barStyle);
    bar.translucent = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) { CVApplyNavigationBarAppearance(bar, black); return; }
#endif
    CVApplyLegacyNavigationBar(bar, black);
}

void CVModernStyleToolbar(UIToolbar *bar)
{
    if (!bar || !CVModernIOS()) return;
    BOOL black = CVIsBlack(bar.barStyle);
    bar.translucent = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) { CVApplyToolbarAppearance(bar, black); return; }
#endif
    CVApplyLegacyToolbar(bar, black);
}

void CVModernStyleSearchBar(UISearchBar *bar)
{
    if (!bar || !CVModernIOS()) return;
    BOOL black = CVIsBlack(bar.barStyle);
    bar.translucent = NO;
    [bar setBackgroundImage:CVBarImage(black, 0, 44)];
    [bar setSearchFieldBackgroundImage:CVSearchFieldImage() forState:UIControlStateNormal];
    [bar setSearchTextPositionAdjustment:UIOffsetMake(4, 0)];
    bar.tintColor = [UIColor whiteColor];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) {
        bar.searchTextField.tintColor = CVRGB(30, 90, 200);
        bar.searchTextField.textColor = [UIColor blackColor];
    }
#endif
}

void CVModernStyleTabBar(UITabBar *bar)
{
    if (!bar || !CVModernIOS()) return;
    bar.translucent = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) { CVApplyTabBarAppearance(bar); return; }
#endif
    [bar setBackgroundImage:CVTabBarImage()];
    [bar setSelectionIndicatorImage:CVTabSelectionImage()];
    [bar setShadowImage:CVClearImage(CGSizeMake(1, 1))];
    [bar setTintColor:CVRGB(235, 45, 55)];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
    if ([bar respondsToSelector:@selector(setUnselectedItemTintColor:)]) [bar setUnselectedItemTintColor:CVRGB(146, 146, 146)];
#endif
}

void CVModernStyleSegmentedControl(UISegmentedControl *seg, BOOL dark)
{
    if (!seg || !CVModernIOS()) return;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13) && [seg respondsToSelector:@selector(setOverrideUserInterfaceStyle:)]) {
        seg.overrideUserInterfaceStyle = dark ? 2 : 1; // 2 = UIUserInterfaceStyleDark
    }
#endif
    [seg setBackgroundImage:CVSegmentImage(NO, dark) forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [seg setBackgroundImage:CVSegmentImage(YES, dark) forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    [seg setBackgroundImage:CVSegmentImage(YES, dark) forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    UIImage *divider = CVSegmentDividerImage(dark);
    [seg setDividerImage:divider forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [seg setDividerImage:divider forLeftSegmentState:UIControlStateSelected rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [seg setDividerImage:divider forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    if (dark) {
        [seg setTitleTextAttributes:CVEmbossedTextAttributes(13) forState:UIControlStateNormal];
        [seg setTitleTextAttributes:CVEmbossedTextAttributes(13) forState:UIControlStateSelected];
    } else {
        [seg setTitleTextAttributes:CVEngravedTextAttributes(13, CVRGB(60, 60, 60)) forState:UIControlStateNormal];
        [seg setTitleTextAttributes:CVEmbossedTextAttributes(13) forState:UIControlStateSelected];
    }
}

#pragma mark - The defaults for every bar (UIAppearance)

static id CVAppearanceInside(Class<UIAppearance> cls, Class container)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
    if ([(id)cls respondsToSelector:@selector(appearanceWhenContainedInInstancesOfClasses:)]) {
        return [cls appearanceWhenContainedInInstancesOfClasses:@[ container ]];
    }
#endif
    return [cls appearanceWhenContainedIn:container, nil];
}

// full-width separators, as before iOS 7
static void CVInstallTableDefaults(void)
{
    [[UITableView appearance] setSeparatorInset:UIEdgeInsetsZero];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
    if ([[UITableView appearance] respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]) {
        [[UITableView appearance] setCellLayoutMarginsFollowReadableWidth:NO];
    }
#endif
}

static void CVInstallAppearance(BOOL black)
{
    // navigation bars, toolbars, tab bars, search bars (the same artwork as the per-bar functions above)
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) {
        CVApplyNavigationBarAppearance([UINavigationBar appearance], black);
        CVApplyToolbarAppearance([UIToolbar appearance], black);
        CVApplyTabBarAppearance([UITabBar appearance]);
    } else
#endif
    {
        CVApplyLegacyNavigationBar([UINavigationBar appearance], black);
        CVApplyLegacyToolbar([UIToolbar appearance], black);
        [[UITabBar appearance] setBackgroundImage:CVTabBarImage()];
        [[UITabBar appearance] setSelectionIndicatorImage:CVTabSelectionImage()];
        [[UITabBar appearance] setTintColor:CVRGB(235, 45, 55)];
    }
    [[UINavigationBar appearance] setTranslucent:NO];
    [[UIToolbar appearance] setTranslucent:NO];
    [[UITabBar appearance] setTranslucent:NO];

    // bordered bar buttons: in navigation bars (as on iOS 6, where plain items were bordered there too) and the
    // Cancel button of search bars; toolbars keep their borderless white glyphs
    CVApplyLegacyBarButtons((UIBarButtonItem *)CVAppearanceInside([UIBarButtonItem class], [UINavigationBar class]), black);
    CVApplyLegacyBarButtons((UIBarButtonItem *)CVAppearanceInside([UIBarButtonItem class], [UISearchBar class]), black);
    [[UIBarButtonItem appearance] setTitleTextAttributes:CVEmbossedTextAttributes(12) forState:UIControlStateNormal];

    [[UISearchBar appearance] setBackgroundImage:CVBarImage(black, 0, 44)];
    [[UISearchBar appearance] setSearchFieldBackgroundImage:CVSearchFieldImage() forState:UIControlStateNormal];
    [[UISearchBar appearance] setSearchTextPositionAdjustment:UIOffsetMake(4, 0)];
    [(UITextField *)CVAppearanceInside([UITextField class], [UISearchBar class]) setTintColor:CVRGB(30, 90, 200)];

    // the iOS 6 blue of switches; glossy gray segmented controls with engraved labels
    [[UISwitch appearance] setOnTintColor:CVRGB(26, 108, 213)];
    UISegmentedControl *segment = [UISegmentedControl appearance];
    [segment setBackgroundImage:CVSegmentImage(NO, black) forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [segment setBackgroundImage:CVSegmentImage(YES, black) forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    [segment setBackgroundImage:CVSegmentImage(YES, black) forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    UIImage *divider = CVSegmentDividerImage(black);
    [segment setDividerImage:divider forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [segment setDividerImage:divider forLeftSegmentState:UIControlStateSelected rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [segment setDividerImage:divider forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    if (black) {
        [segment setTitleTextAttributes:CVEmbossedTextAttributes(13) forState:UIControlStateNormal];
        [segment setTitleTextAttributes:CVEmbossedTextAttributes(13) forState:UIControlStateSelected];
    } else {
        [segment setTitleTextAttributes:CVEngravedTextAttributes(13, CVRGB(60, 60, 60)) forState:UIControlStateNormal];
        [segment setTitleTextAttributes:CVEmbossedTextAttributes(13) forState:UIControlStateSelected];
    }
    CVInstallTableDefaults();
}

#pragma mark - iOS 13: full-screen modals and rounded grouped tables

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
static void (*CVOriginalPresent)(id, SEL, UIViewController *, BOOL, void (^)(void));
static id (*CVOriginalTableInit)(id, SEL, CGRect, UITableViewStyle);

// The app's own view controllers (also wrapped in a navigation or tab bar controller), not UIKit's pickers and sheets
static BOOL CVIsAppController(UIViewController *vc)
{
    UIViewController *probe = vc;
    if ([vc isKindOfClass:[UINavigationController class]]) probe = ((UINavigationController *)vc).viewControllers.firstObject ?: vc;
    else if ([vc isKindOfClass:[UITabBarController class]]) probe = ((UITabBarController *)vc).viewControllers.firstObject ?: vc;
    // (the bundle of a class from the executable is the main bundle; a system picker or sheet lives under /System)
    NSBundle *bundle = [NSBundle bundleForClass:[probe class]];
    if (bundle == [NSBundle mainBundle]) return YES;
    NSString *path = bundle.bundlePath ?: @"";
    return path.length && ![path hasPrefix:@"/System/"] && ![path hasPrefix:@"/Developer/"] && ![path hasPrefix:@"/usr/"];
}

static void CVPresent(id self, SEL _cmd, UIViewController *vc, BOOL animated, void (^completion)(void))
{
    // iOS 13 made the default a card that slides up and can be dragged away; iOS 6 presented full screen
    if (vc && vc.modalPresentationStyle == UIModalPresentationAutomatic && CVIsAppController(vc)) {
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    CVOriginalPresent(self, _cmd, vc, animated, completion);
}

static id CVTableInit(id self, SEL _cmd, CGRect frame, UITableViewStyle style)
{
    // iOS 13 draws grouped tables as full-width flat lists; the inset style keeps the rounded groups of iOS 6
    if (style == UITableViewStyleGrouped) {
        self = CVOriginalTableInit(self, _cmd, frame, UITableViewStyleInsetGrouped);
        [self setBackgroundColor:CVRGB(197, 204, 212)];
        return self;
    }
    return CVOriginalTableInit(self, _cmd, frame, style);
}

static void CVInstallIOS13Behaviour(void)
{
    Method present = class_getInstanceMethod([UIViewController class], @selector(presentViewController:animated:completion:));
    if (present && !CVOriginalPresent) {
        CVOriginalPresent = (void (*)(id, SEL, UIViewController *, BOOL, void (^)(void)))method_getImplementation(present);
        method_setImplementation(present, (IMP)CVPresent);
    }
    Method tableInit = class_getInstanceMethod([UITableView class], @selector(initWithFrame:style:));
    if (tableInit && !CVOriginalTableInit) {
        CVOriginalTableInit = (id (*)(id, SEL, CGRect, UITableViewStyle))method_getImplementation(tableInit);
        method_setImplementation(tableInit, (IMP)CVTableInit);
    }
}
#endif

#pragma mark - Tables

void CVModernSetTableViewDark(UITableView *tableView, BOOL dark)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    // (the forced light style of the app would draw dark grey section headers on a dark table)
    if (CVAtLeast(13)) tableView.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
#endif
}

void CVModernSetCellDark(UITableViewCell *cell, BOOL dark)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) cell.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
#endif
}
#pragma mark - Set-up

static BOOL CVsetUpDone = NO;

void CVModernSetUp(UIBarStyle defaultBarStyle)
{
    if (!CVModernIOS() || CVsetUpDone) return;
    CVsetUpDone = YES;
    CVInstallAppearance(CVIsBlack(defaultBarStyle));
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) CVInstallIOS13Behaviour();
#endif
    NSLog(@"[CVModern] iOS %@: the iOS 6 look is on", [UIDevice currentDevice].systemVersion);
}

void CVModernSetUpWithoutSkin(void)
{
    if (!CVModernIOS() || CVsetUpDone) return;
    CVsetUpDone = YES;
    CVInstallTableDefaults();
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (CVAtLeast(13)) CVInstallIOS13Behaviour();
#endif
    NSLog(@"[CVModern] iOS %@: iOS 6 behaviour on (the app's own look)", [UIDevice currentDevice].systemVersion);
}

void CVModernRequestNotificationPermission(void)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    UIApplication *app = [UIApplication sharedApplication];
    if (CVAtLeast(8) && [app respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType types = UIUserNotificationTypeAlert | UIUserNotificationTypeSound | UIUserNotificationTypeBadge;
        [app registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:types categories:nil]];
    }
#endif
}
