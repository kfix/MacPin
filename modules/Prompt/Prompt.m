//
//  Prompt.m
//  swift-libedit
//
//  Created by Neil Pankey on 6/10/14.
//  Copyright (c) 2014 Neil Pankey. All rights reserved.
//

#import "Prompt.h"

#import <histedit.h>
// `man editline`

char* prompt(EditLine *e) {
    return "> ";
}

@implementation Prompt

EditLine* _el;
History* _hist;
HistEvent _ev;

- (instancetype) initWithArgv0:(const char*)argv0 {
    if (self = [super init]) {
        // Setup the editor
        _el = el_init(argv0, stdin, stdout, stderr);
        el_set(_el, EL_PROMPT, &prompt);
        el_set(_el, EL_EDITOR, "emacs");
        
        // With support for history
        _hist = history_init();
        history(_hist, &_ev, H_SETSIZE, 800);
        el_set(_el, EL_HIST, history, _hist);
    }
    
    return self;
}

- (void) dealloc {
    if (_hist != NULL) {
        history_end(_hist);
        _hist = NULL;
    }
    
    if (_el != NULL) {
        el_end(_el);
        _el = NULL;
    }
	[super dealloc];
}

- (NSString*) gets {
    
    // line includes the trailing newline
    int count;
    const char* line = el_gets(_el, &count);
    
    if (count > 0) {
        history(_hist, &_ev, H_ENTER, line);
        
        return [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
    }

    return nil;
}

@end
