//
//  JBLineChartLinesView.m
//  JBChartViewDemo
//
//  Created by Terry Worona on 12/26/15.
//  Copyright © 2015 Jawbone. All rights reserved.
//

#import "JBLineChartLinesView.h"

// Layers
#import "JBGradientLineLayer.h"
#import "JBShapeLayer.h"

// Models
#import "JBLineChartLine.h"
#import "JBLineChartPoint.h"

// Numerics
CGFloat const kJBLineChartLinesViewMiterLimit = -5.0;
CGFloat const kJBLineChartLinesViewSmoothThresholdSlope = 0.01f;
CGFloat const kJBLineChartLinesViewReloadDataAnimationDuration = 0.15f;
NSInteger const kJBLineChartLinesViewSmoothThresholdVertical = 1;
NSInteger const kJBLineChartLinesViewUnselectedLineIndex = -1;

@interface JBLineChartLinesView ()

@property (nonatomic, assign) BOOL animated; // for reload

// Getters
- (UIBezierPath *)bezierPathForLineChartLine:(JBLineChartLine *)lineChartLine filled:(BOOL)filled;
- (JBShapeLayer *)shapeLayerForLineIndex:(NSUInteger)lineIndex filled:(BOOL)filled;
- (JBGradientLineLayer *)gradientLineLayerForLineIndex:(NSUInteger)lineIndex filled:(BOOL)filled;
- (CABasicAnimation *)basicPathAnimationFromBezierPath:(UIBezierPath *)fromBezierPath toBezierPath:(UIBezierPath *)toBezierPath;

@end

@implementation JBLineChartLinesView

#pragma mark - Alloc/Init

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self)
	{
		self.backgroundColor = [UIColor clearColor];
	}
	return self;
}

#pragma mark - Memory Management

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
	[super drawRect:rect];
	
	NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesForLineChartLinesView:)], @"JBLineChartLinesView // delegate must implement - (NSArray *)lineChartLinesForLineChartLinesView:(JBLineChartLinesView *)lineChartLinesView");
	NSArray *chartData = [self.delegate lineChartLinesForLineChartLinesView:self];
	
	for (int lineIndex=0; lineIndex<[chartData count]; lineIndex++)
	{
		JBLineChartLine *lineChartLine = [chartData objectAtIndex:lineIndex];
		{
			UIBezierPath *linePath = [self bezierPathForLineChartLine:lineChartLine filled:NO];
			UIBezierPath *fillPath = [self bezierPathForLineChartLine:lineChartLine filled:YES];
			
			if (linePath == nil || fillPath == nil)
			{
				continue;
			}
			
			JBShapeLayer *shapeLayer = [self shapeLayerForLineIndex:lineIndex filled:NO];
			if (shapeLayer == nil)
			{
				shapeLayer = [[JBShapeLayer alloc] initWithTag:lineIndex filled:NO smoothedLine:lineChartLine.smoothedLine lineStyle:lineChartLine.lineStyle currentPath:linePath];
			}
			
			JBShapeLayer *fillLayer = [self shapeLayerForLineIndex:lineIndex filled:YES];
			if (fillLayer == nil)
			{
				fillLayer = [[JBShapeLayer alloc] initWithTag:lineIndex filled:YES smoothedLine:lineChartLine.smoothedLine lineStyle:lineChartLine.lineStyle currentPath:nil]; // path not needed for fills (unsupported)
			}
			
			// Width
			NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:widthForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CGFloat)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView widthForLineAtLineIndex:(NSUInteger)lineIndex");
			shapeLayer.lineWidth = [self.delegate lineChartLinesView:self widthForLineAtLineIndex:lineIndex];
			
			NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:widthForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CGFloat)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView widthForLineAtLineIndex:(NSUInteger)lineIndex");
			fillLayer.lineWidth = [self.delegate lineChartLinesView:self widthForLineAtLineIndex:lineIndex];
			
			// Colors
			NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:colorForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (UIColor *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView colorForLineAtLineIndex:(NSUInteger)lineIndex");
			shapeLayer.strokeColor = [self.delegate lineChartLinesView:self colorForLineAtLineIndex:lineIndex].CGColor;
			
			NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:fillColorForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (UIColor *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView fillColorForLineAtLineIndex:(NSUInteger)lineIndex");
			fillLayer.fillColor = [self.delegate lineChartLinesView:self fillColorForLineAtLineIndex:lineIndex].CGColor;
			
			// Bounds
			shapeLayer.frame = self.bounds;
			fillLayer.frame = self.bounds;

			// Note: fills go first because the lines must go on top
			
			/*
			 * Solid fill
			 */
			if (lineChartLine.fillColorStyle == JBLineChartViewColorStyleSolid)
			{
				fillLayer.path = fillPath.CGPath;
				[self.layer addSublayer:fillLayer];
			}
			
			/*
			 * Gradient fill
			 */
			else if (lineChartLine.fillColorStyle == JBLineChartViewColorStyleGradient)
			{
				JBGradientLineLayer *gradientLineFillLayer = [self gradientLineLayerForLineIndex:lineIndex filled:YES];
				if (gradientLineFillLayer == nil)
				{
					NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:fillGradientForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CAGradientLayer *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView fillGradientForLineAtLineIndex:(NSUInteger)lineIndex");
					gradientLineFillLayer = [[JBGradientLineLayer alloc] initWithGradientLayer:[self.delegate lineChartLinesView:self fillGradientForLineAtLineIndex:lineIndex] tag:lineIndex filled:YES currentPath:nil];
				}
				gradientLineFillLayer.frame = fillLayer.frame;
				
				fillLayer.path = fillPath.CGPath;
				CGColorRef shapeLayerStrokeColor = shapeLayer.strokeColor;
				shapeLayer.strokeColor = [UIColor colorWithWhite:1 alpha:[gradientLineFillLayer alpha]].CGColor; // mask uses alpha only
				gradientLineFillLayer.mask = fillLayer;
				[self.layer addSublayer:gradientLineFillLayer];
				
				// Refresh shape layer stroke (used below)
				shapeLayer.strokeColor = shapeLayerStrokeColor;
			}
			
			/*
			 * Solid line
			 */
			if (lineChartLine.colorStyle == JBLineChartViewColorStyleSolid)
			{
				if (self.animated)
				{
					[shapeLayer addAnimation:[self basicPathAnimationFromBezierPath:shapeLayer.currentPath toBezierPath:linePath] forKey:@"shapeLayerPathAnimation"];
				}
				else
				{
					shapeLayer.path = linePath.CGPath;
				}
				
				shapeLayer.currentPath = [linePath copy];
				[self.layer addSublayer:shapeLayer];
			}
			
			/*
			 * Gradient line
			 */
			else if (lineChartLine.colorStyle == JBLineChartViewColorStyleGradient)
			{
				JBGradientLineLayer *gradientLineLayer = [self gradientLineLayerForLineIndex:lineIndex filled:NO];
				if (gradientLineLayer == nil)
				{
					NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:gradientForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CAGradientLayer *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView gradientForLineAtLineIndex:(NSUInteger)lineIndex");
					gradientLineLayer = [[JBGradientLineLayer alloc] initWithGradientLayer:[self.delegate lineChartLinesView:self gradientForLineAtLineIndex:lineIndex] tag:lineIndex filled:NO currentPath:linePath];
				}
				gradientLineLayer.frame = shapeLayer.frame;

				if (self.animated)
				{
					[gradientLineLayer.mask addAnimation:[self basicPathAnimationFromBezierPath:gradientLineLayer.currentPath toBezierPath:linePath] forKey:@"gradientLayerMaskAnimation"];
				}
				else
				{
					shapeLayer.path = linePath.CGPath;
					shapeLayer.strokeColor = [UIColor colorWithWhite:1 alpha:[gradientLineLayer alpha]].CGColor; // mask uses alpha only
					gradientLineLayer.mask = shapeLayer;
				}
				
				gradientLineLayer.currentPath = [linePath copy];
				[self.layer addSublayer:gradientLineLayer];
			}
		}
	}
	
	self.animated = NO;
}

#pragma mark - Data

- (void)reloadDataAnimated:(BOOL)animated callback:(void (^)())callback
{
	NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesForLineChartLinesView:)], @"JBLineChartLinesView // delegate must implement - (NSArray *)lineChartLinesForLineChartLinesView:(JBLineChartLinesView *)lineChartLinesView");
	NSArray *chartData = [self.delegate lineChartLinesForLineChartLinesView:self];
	
	NSUInteger lineCount = [chartData count];
	
	__weak JBLineChartLinesView* weakSelf = self;
	
	dispatch_block_t completionBlock = ^{
		weakSelf.animated = animated;
		[weakSelf setNeedsDisplay]; // re-draw layers
		if (callback)
		{
			callback();
		}
	};
	
	// Mark layers for animation or removal
	NSMutableArray *mutableRemovedLayers = [NSMutableArray array];
	for (CALayer *layer in [self.layer sublayers])
	{
		BOOL removeLayer = NO;
		
		if ([layer isKindOfClass:[JBShapeLayer class]])
		{
			removeLayer = (((JBShapeLayer *)layer).tag >= lineCount);
		}
		else if ([layer isKindOfClass:[JBGradientLineLayer class]])
		{
			removeLayer = (((JBGradientLineLayer *)layer).tag >= lineCount);
		}
		
		if (removeLayer)
		{
			[mutableRemovedLayers addObject:layer];
		}
	}
	
	// Remove legacy layers
	NSArray *removedLayers = [NSArray arrayWithArray:mutableRemovedLayers];
	if ([removedLayers count] > 0)
	{
		for (int index=0; index<[removedLayers count]; index++)
		{
			CALayer *removedLayer = [removedLayers objectAtIndex:index];
			
			if (animated)
			{
				[CATransaction begin];
				{
					CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
					animation.fromValue = [NSNumber numberWithFloat:1.0f];
					animation.toValue = [NSNumber numberWithFloat:0.0f];
					animation.duration = kJBLineChartLinesViewReloadDataAnimationDuration;
					animation.timingFunction = [CAMediaTimingFunction functionWithName:@"easeInEaseOut"];
					animation.fillMode = kCAFillModeBoth;
					animation.removedOnCompletion = NO;
					
					[CATransaction setCompletionBlock:^{
						[removedLayer removeFromSuperlayer];
						if (index == [removedLayers count]-1)
						{
							completionBlock();
						}
					}];
					
					[removedLayer addAnimation:animation forKey:@"removeShapeLayerAnimation"];
				}
				[CATransaction commit];
			}
			else
			{
				[removedLayer removeFromSuperlayer];
				if (index == [removedLayers count]-1)
				{
					completionBlock();
				}
			}
		}
	}
	else
	{
		completionBlock();
	}
}

- (void)reloadDataAnimated:(BOOL)animated
{
	[self reloadDataAnimated:animated callback:nil];
}

- (void)reloadData
{
	[self reloadDataAnimated:NO];
}

#pragma mark - Setters

- (void)setSelectedLineIndex:(NSInteger)selectedLineIndex animated:(BOOL)animated
{
	_selectedLineIndex = selectedLineIndex;
	
	__weak JBLineChartLinesView* weakSelf = self;
	
	dispatch_block_t adjustLines = ^{
		NSMutableArray *layersToReplace = [NSMutableArray array];
		
		NSString * const oldLayerKey = @"oldLayer";
		NSString * const newLayerKey = @"newLayer";
		
		for (CALayer *layer in [weakSelf.layer sublayers])
		{
			/*
			 * Solid line or fill
			 */
			if ([layer isKindOfClass:[JBShapeLayer class]])
			{
				JBShapeLayer *shapeLayer = (JBShapeLayer * )layer;
				
				if (shapeLayer.filled)
				{
					// Selected solid fill
					if (shapeLayer.tag == weakSelf.selectedLineIndex)
					{
						NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:selectionFillColorForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (UIColor *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView selectionFillColorForLineAtLineIndex:(NSUInteger)lineIndex");
						shapeLayer.fillColor = [self.delegate lineChartLinesView:self selectionFillColorForLineAtLineIndex:shapeLayer.tag].CGColor;
						shapeLayer.opacity = 1.0f;
					}
					// Unselected solid fill
					else
					{
						NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:fillColorForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (UIColor *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView fillColorForLineAtLineIndex:(NSUInteger)lineIndex");
						shapeLayer.fillColor = [self.delegate lineChartLinesView:self fillColorForLineAtLineIndex:shapeLayer.tag].CGColor;
						
						NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:dimmedSelectionOpacityAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CGFloat)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView dimmedSelectionOpacityAtLineIndex:(NSUInteger)lineIndex");
						shapeLayer.opacity = (weakSelf.selectedLineIndex == kJBLineChartLinesViewUnselectedLineIndex) ? 1.0f : [self.delegate lineChartLinesView:self dimmedSelectionOpacityAtLineIndex:shapeLayer.tag];
					}
				}
				else
				{
					// Selected solid line
					if (shapeLayer.tag == weakSelf.selectedLineIndex)
					{
						NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:selectionColorForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (UIColor *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView selectionColorForLineAtLineIndex:(NSUInteger)lineIndex");
						shapeLayer.strokeColor = [self.delegate lineChartLinesView:self selectionColorForLineAtLineIndex:shapeLayer.tag].CGColor;
						shapeLayer.opacity = 1.0f;
					}
					// Unselected solid line
					else
					{
						NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:colorForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (UIColor *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView colorForLineAtLineIndex:(NSUInteger)lineIndex");
						shapeLayer.strokeColor = [self.delegate lineChartLinesView:self colorForLineAtLineIndex:shapeLayer.tag].CGColor;
						
						NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:dimmedSelectionOpacityAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CGFloat)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView dimmedSelectionOpacityAtLineIndex:(NSUInteger)lineIndex");
						shapeLayer.opacity = (weakSelf.selectedLineIndex == kJBLineChartLinesViewUnselectedLineIndex) ? 1.0f : [self.delegate lineChartLinesView:self dimmedSelectionOpacityAtLineIndex:shapeLayer.tag];
					}
				}
			}
			
			/*
			 * Gradient line or fill
			 */
			else if ([layer isKindOfClass:[CAGradientLayer class]])
			{
				CAGradientLayer *gradientLayer = (CAGradientLayer * )layer;
				
				if ([gradientLayer.mask isKindOfClass:[JBShapeLayer class]])
				{
					JBShapeLayer *shapeLayer = (JBShapeLayer * )gradientLayer.mask;
					
					if (shapeLayer.filled)
					{
						// Selected gradient fill
						if (shapeLayer.tag == weakSelf.selectedLineIndex)
						{
							NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:selectionFillGradientForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CAGradientLayer *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView selectionFillGradientForLineAtLineIndex:(NSUInteger)lineIndex");
							CAGradientLayer *selectedFillGradient = [self.delegate lineChartLinesView:self selectionFillGradientForLineAtLineIndex:shapeLayer.tag];
							selectedFillGradient.frame = layer.frame;
							selectedFillGradient.mask = layer.mask;
							selectedFillGradient.opacity = 1.0f;
							[layersToReplace addObject:@{oldLayerKey: layer, newLayerKey: selectedFillGradient}];
						}
						// Unselected gradient fill
						else
						{
							NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:fillGradientForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CAGradientLayer *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView fillGradientForLineAtLineIndex:(NSUInteger)lineIndex");
							CAGradientLayer *unselectedFillGradient = [self.delegate lineChartLinesView:self fillGradientForLineAtLineIndex:shapeLayer.tag];
							unselectedFillGradient.frame = layer.frame;
							unselectedFillGradient.mask = layer.mask;
							NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:dimmedSelectionOpacityAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CGFloat)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView dimmedSelectionOpacityAtLineIndex:(NSUInteger)lineIndex");
							unselectedFillGradient.opacity = (weakSelf.selectedLineIndex == kJBLineChartLinesViewUnselectedLineIndex) ? 1.0f : [self.delegate lineChartLinesView:self dimmedSelectionOpacityAtLineIndex:shapeLayer.tag];
							[layersToReplace addObject:@{oldLayerKey: layer, newLayerKey: unselectedFillGradient}];
						}
					}
					else
					{
						// Selected gradient line
						if (shapeLayer.tag == weakSelf.selectedLineIndex)
						{
							NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:selectionGradientForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CAGradientLayer *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView selectionGradientForLineAtLineIndex:(NSUInteger)lineIndex");
							CAGradientLayer *selectedGradient = [self.delegate lineChartLinesView:self selectionGradientForLineAtLineIndex:shapeLayer.tag];
							selectedGradient.frame = layer.frame;
							selectedGradient.mask = layer.mask;
							selectedGradient.opacity = 1.0f;
							[layersToReplace addObject:@{oldLayerKey: layer, newLayerKey: selectedGradient}];
						}
						// Unselected gradient line
						else
						{
							NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:gradientForLineAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CAGradientLayer *)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView gradientForLineAtLineIndex:(NSUInteger)lineIndex");
							CAGradientLayer *unselectedGradient = [self.delegate lineChartLinesView:self gradientForLineAtLineIndex:shapeLayer.tag];
							unselectedGradient.frame = layer.frame;
							unselectedGradient.mask = layer.mask;
							NSAssert([self.delegate respondsToSelector:@selector(lineChartLinesView:dimmedSelectionOpacityAtLineIndex:)], @"JBLineChartLinesView // delegate must implement - (CGFloat)lineChartLinesView:(JBLineChartLinesView *)lineChartLinesView dimmedSelectionOpacityAtLineIndex:(NSUInteger)lineIndex");
							shapeLayer.opacity = (weakSelf.selectedLineIndex == kJBLineChartLinesViewUnselectedLineIndex) ? 1.0f : [self.delegate lineChartLinesView:self dimmedSelectionOpacityAtLineIndex:shapeLayer.tag];
							[layersToReplace addObject:@{oldLayerKey: layer, newLayerKey: unselectedGradient}];
						}
					}
				}
			}
		}
		
		for (NSDictionary *layerPair in layersToReplace)
		{
			[weakSelf.layer replaceSublayer:layerPair[oldLayerKey] with:layerPair[newLayerKey]];
		}
	};
	
	if (animated)
	{
		[UIView animateWithDuration:kJBChartViewDefaultAnimationDuration animations:^{
			adjustLines();
		}];
	}
	else
	{
		adjustLines();
	}
}

- (void)setSelectedLineIndex:(NSInteger)selectedLineIndex
{
	[self setSelectedLineIndex:selectedLineIndex animated:NO];
}

#pragma mark - Getters

- (UIBezierPath *)bezierPathForLineChartLine:(JBLineChartLine *)lineChartLine filled:(BOOL)filled
{
	if ([lineChartLine.lineChartPoints count] > 0)
	{
		UIBezierPath *bezierPath = [UIBezierPath bezierPath];
		
		bezierPath.miterLimit = kJBLineChartLinesViewMiterLimit;
		
		JBLineChartPoint *previousLineChartPoint = nil;
		CGFloat previousSlope = 0.0f;
		
		BOOL visiblePointFound = NO;
		NSArray *sortedLineChartPoints = [lineChartLine.lineChartPoints sortedArrayUsingSelector:@selector(compare:)];
		CGFloat firstXPosition = 0.0f;
		CGFloat firstYPosition = 0.0f;
		CGFloat lastXPosition = 0.0f;
		CGFloat lastYPosition = 0.0f;
		
		for (NSUInteger index=0; index<[sortedLineChartPoints count]; index++)
		{
			JBLineChartPoint *lineChartPoint = [sortedLineChartPoints objectAtIndex:index];
			
			if (lineChartPoint.hidden)
			{
				continue;
			}
			
			if (!visiblePointFound)
			{
				[bezierPath moveToPoint:CGPointMake(lineChartPoint.position.x, lineChartPoint.position.y)];
				firstXPosition = lineChartPoint.position.x;
				firstYPosition = lineChartPoint.position.y;
				visiblePointFound = YES;
			}
			else
			{
				JBLineChartPoint *nextLineChartPoint = nil;
				if (index != ([lineChartLine.lineChartPoints count] - 1))
				{
					nextLineChartPoint = [sortedLineChartPoints objectAtIndex:(index + 1)];
				}
				
				CGFloat nextSlope = (nextLineChartPoint != nil) ? ((nextLineChartPoint.position.y - lineChartPoint.position.y)) / ((nextLineChartPoint.position.x - lineChartPoint.position.x)) : previousSlope;
				CGFloat currentSlope = ((lineChartPoint.position.y - previousLineChartPoint.position.y)) / (lineChartPoint.position.x-previousLineChartPoint.position.x);
				
				BOOL deltaFromNextSlope = ((currentSlope >= (nextSlope + kJBLineChartLinesViewSmoothThresholdSlope)) || (currentSlope <= (nextSlope - kJBLineChartLinesViewSmoothThresholdSlope)));
				BOOL deltaFromPreviousSlope = ((currentSlope >= (previousSlope + kJBLineChartLinesViewSmoothThresholdSlope)) || (currentSlope <= (previousSlope - kJBLineChartLinesViewSmoothThresholdSlope)));
				BOOL deltaFromPreviousY = (lineChartPoint.position.y >= previousLineChartPoint.position.y + kJBLineChartLinesViewSmoothThresholdVertical) || (lineChartPoint.position.y <= previousLineChartPoint.position.y - kJBLineChartLinesViewSmoothThresholdVertical);
				
				if (lineChartLine.smoothedLine && deltaFromNextSlope && deltaFromPreviousSlope && deltaFromPreviousY)
				{
					CGFloat deltaX = lineChartPoint.position.x - previousLineChartPoint.position.x;
					CGFloat controlPointX = previousLineChartPoint.position.x + (deltaX / 2);
					
					CGPoint controlPoint1 = CGPointMake(controlPointX, previousLineChartPoint.position.y);
					CGPoint controlPoint2 = CGPointMake(controlPointX, lineChartPoint.position.y);
					
					[bezierPath addCurveToPoint:CGPointMake(lineChartPoint.position.x, lineChartPoint.position.y) controlPoint1:controlPoint1 controlPoint2:controlPoint2];
				}
				else
				{
					[bezierPath addLineToPoint:CGPointMake(lineChartPoint.position.x, lineChartPoint.position.y)];
				}
				
				lastXPosition = lineChartPoint.position.x;
				lastYPosition = lineChartPoint.position.y;
				previousSlope = currentSlope;
			}
			previousLineChartPoint = lineChartPoint;
		}
		
		if (filled)
		{
			UIBezierPath *filledBezierPath = [bezierPath copy];
			
			if(visiblePointFound)
			{
				[filledBezierPath addLineToPoint:CGPointMake(lastXPosition, lastYPosition)];
				[filledBezierPath addLineToPoint:CGPointMake(lastXPosition, self.bounds.size.height)];
				
				[filledBezierPath addLineToPoint:CGPointMake(firstXPosition, self.bounds.size.height)];
				[filledBezierPath addLineToPoint:CGPointMake(firstXPosition, firstYPosition)];
			}
			
			return filledBezierPath;
		}
		else
		{
			return bezierPath;
		}
	}
	return nil;
}

- (JBShapeLayer *)shapeLayerForLineIndex:(NSUInteger)lineIndex filled:(BOOL)filled
{
	for (CALayer *layer in [self.layer sublayers])
	{
		if ([layer isKindOfClass:[JBShapeLayer class]])
		{
			if (((JBShapeLayer *)layer).tag == lineIndex && ((JBShapeLayer *)layer).filled == filled)
			{
				return (JBShapeLayer *)layer;
			}
		}
	}
	return nil;
}

- (JBGradientLineLayer *)gradientLineLayerForLineIndex:(NSUInteger)lineIndex filled:(BOOL)filled
{
	for (CALayer *layer in [self.layer sublayers])
	{
		if ([layer isKindOfClass:[JBGradientLineLayer class]])
		{
			if (((JBGradientLineLayer *)layer).tag == lineIndex && ((JBGradientLineLayer *)layer).filled == filled)
			{
				return (JBGradientLineLayer *)layer;
			}
		}
	}
	return nil;
}

- (CABasicAnimation *)basicPathAnimationFromBezierPath:(UIBezierPath *)fromBezierPath toBezierPath:(UIBezierPath *)toBezierPath
{
	CABasicAnimation *basicPathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
	basicPathAnimation.fromValue = (id)fromBezierPath.CGPath;
	basicPathAnimation.toValue = (id)toBezierPath.CGPath;
	basicPathAnimation.duration = kJBLineChartLinesViewReloadDataAnimationDuration;
	basicPathAnimation.timingFunction = [CAMediaTimingFunction functionWithName:@"easeInEaseOut"];
	basicPathAnimation.fillMode = kCAFillModeBoth;
	basicPathAnimation.removedOnCompletion = NO;
	return basicPathAnimation;
}

#pragma mark - Callback Helpers

- (void)fireCallback:(void (^)())callback
{
	dispatch_block_t callbackCopy = [callback copy];
	
	if (callbackCopy != nil)
	{
		callbackCopy();
	}
}

@end
