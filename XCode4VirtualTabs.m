#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

static IMP original_doCommandBySelector = nil;
typedef void (*selectorFunction)(id, SEL, SEL);

@interface XCode4VirtualTabs : NSObject
@end

@implementation XCode4VirtualTabs
static void doCommandBySelector( id self_, SEL _cmd, SEL selector )
{
	do {
		bool selectionModified = (selector == @selector(moveToBeginningOfLineAndModifySelection:)) ||
			(selector == @selector(moveToLeftEndOfLineAndModifySelection:));
		
		if (selector == @selector(moveToBeginningOfLine:) ||
            selector == @selector(moveToLeftEndOfLine:) || selectionModified)
		{
			NSTextView *self = (NSTextView *)self_;
			NSString *text = self.string;
			NSRange selectedRange = self.selectedRange;
			NSRange lineRange = [text lineRangeForRange:selectedRange];
			
			if (lineRange.length == 0)
				break;
			
			NSString *line = [text substringWithRange:lineRange];
			NSRange codeStartRange = [line rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]];
			
			if (codeStartRange.location == NSNotFound)
				break;
			
			NSUInteger caretLocation = selectedRange.location - lineRange.location;
			if (caretLocation < codeStartRange.location && caretLocation != 0)
				break;
			
			int start = lineRange.location;
			if (selectedRange.location != (lineRange.location + codeStartRange.location))
				start += codeStartRange.location;
			
			int end = selectionModified ? (selectedRange.location + selectedRange.length) : start;
			
			if (end - start < 0)
				break;
			
            NSRange range = NSMakeRange(start, end - start);
			
			[self setSelectedRange:range];
			[self scrollRangeToVisible:range];
			return;
		}
		else if (selector == @selector(moveLeft:) ||
				 selector == @selector(moveRight:))
		{
			NSTextView *self = (NSTextView *)self_;
			NSString *text = self.string;
			NSRange selectedRange = self.selectedRange;
			NSRange lineRange = [text lineRangeForRange:selectedRange];

			NSString *line = [text substringWithRange:lineRange];
			NSRange codeStartRange = [line rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]];

			if (codeStartRange.location == NSNotFound)
				break;

			NSUInteger caretLocation = selectedRange.location - lineRange.location;
			
			if (selector == @selector(moveLeft:)) {
				if (caretLocation != 0 && caretLocation <= codeStartRange.location) {
					char previousCharacter = [text characterAtIndex:selectedRange.location - 1];
					if (previousCharacter == ' ') {
						NSInteger newCaretlocation = ((caretLocation/4) - 1)*4;
						if (newCaretlocation < 0) {
							newCaretlocation = 0;
						}
						NSRange range = NSMakeRange(selectedRange.location + (newCaretlocation - caretLocation), 0);
						[self setSelectedRange:range];
						[self scrollRangeToVisible:range];
						return;
					}
				}
			}
			else if (selector == @selector(moveRight:)) {
				if (caretLocation < codeStartRange.location) {
					char nextCharacter = [text characterAtIndex:selectedRange.location + 1];
					if (nextCharacter == ' ') {
						NSInteger newCaretlocation = ((caretLocation/4) + 1)*4;
						if (newCaretlocation > codeStartRange.location) {
							newCaretlocation = codeStartRange.location;
						}
						NSRange range = NSMakeRange(selectedRange.location + (newCaretlocation - caretLocation), 0);
						[self setSelectedRange:range];
						[self scrollRangeToVisible:range];
						return;
					}
				}
			}
		}
	} while (0);
	
    return ((selectorFunction)original_doCommandBySelector)(self_, _cmd, selector);
}

+ (void) pluginDidLoad:(NSBundle *)plugin
{
    Class class = nil;
    Method originalMethod = nil;
    
    NSLog(@"%@ initializing...", NSStringFromClass([self class]));
    
    if (!(class = NSClassFromString(@"DVTSourceTextView")))
        goto failed;
    
    if (!(originalMethod = class_getInstanceMethod(class, @selector(doCommandBySelector:))))
        goto failed;
    
    if (!(original_doCommandBySelector = method_setImplementation(originalMethod, (IMP)&doCommandBySelector)))
        goto failed;
    
    NSLog(@"%@ complete!", NSStringFromClass([self class]));
    return;
    
failed:
    NSLog(@"%@ failed. :(", NSStringFromClass([self class]));
}
@end
