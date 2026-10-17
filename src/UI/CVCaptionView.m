#import "CVCaptionView.h"

@interface CVCaptionView ()
@property (nonatomic, strong) UIView *capsuleView;
@property (nonatomic, strong) UILabel *label;
@end

@implementation CVCaptionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];

        _capsuleView = [[UIView alloc] init];
        _capsuleView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
        _capsuleView.layer.cornerRadius = 6.0;
        _capsuleView.clipsToBounds = YES;
        _capsuleView.hidden = YES;
        [self addSubview:_capsuleView];

        _label = [[UILabel alloc] init];
        _label.font = [UIFont boldSystemFontOfSize:15];
        _label.textColor = [UIColor whiteColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.numberOfLines = 3;
        _label.backgroundColor = [UIColor clearColor];
        [_capsuleView addSubview:_label];
    }
    return self;
}

- (void)setText:(NSString *)text
{
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) {
        self.capsuleView.hidden = YES;
        self.label.text = @"";
        return;
    }

    self.label.text = text;
    self.capsuleView.hidden = NO;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.capsuleView.hidden) return;

    CGFloat maxW = self.bounds.size.width - 40;
    CGSize fit = [self.label.text sizeWithFont:self.label.font constrainedToSize:CGSizeMake(maxW, 80) lineBreakMode:NSLineBreakByWordWrapping];

    CGFloat capW = fit.width + 20;
    CGFloat capH = fit.height + 12;
    CGFloat capX = (self.bounds.size.width - capW) / 2.0;
    CGFloat capY = self.bounds.size.height - capH - 12;

    self.capsuleView.frame = CGRectMake(capX, capY, capW, capH);
    self.label.frame = CGRectMake(10, 6, fit.width, fit.height);
}

@end
