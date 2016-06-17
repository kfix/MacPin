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

#include <termios.h>

const char * el_prompt = "> " ;
const char* prompter(EditLine *e) {
    return el_prompt;
}
const char * historypath;

struct termios ttyopts;

void exceptionHandler(NSException *exception) {
    // app crashed mid-prompt, so lets restore the term
    tcsetattr(1, TCSANOW, &ttyopts);
    return;
}

void signalHandler(int sig) {
    // app crashed mid-prompt, so lets restore the term
	//term.c_oflag &= ~ECHO // `stty echo`
    tcsetattr(1, TCSANOW, &ttyopts);
    signal(sig, SIG_DFL); // uninstall sighandler
    return;
}

@implementation Prompt

EditLine* _el;
History* _hist;
HistEvent _ev;

- (instancetype) initWithArgv0:(const char*)argv0 prompt:(NSString *)prompt {
    if (self = [super init]) {
    	tcgetattr(1, &ttyopts); // backup original terminal settings in case we crash
        historypath = [[NSTemporaryDirectory() stringByAppendingString:@".REPL_history"] UTF8String];
        el_prompt = [[NSString stringWithFormat:@"<%s> %@", argv0, prompt] UTF8String];
        // Setup the editor
        _el = el_init(argv0, stdin, stdout, stderr); // argv0 designates the .editrc app-name cfgs to use
        el_set(_el, EL_PROMPT, &prompter);
        el_set(_el, EL_EDITOR, "emacs");

        // With support for history
        _hist = history_init();
        history(_hist, &_ev, H_SETSIZE, 800);
        el_set(_el, EL_HIST, history, _hist);
        history(_hist, &_ev, H_LOAD, historypath);
    }

    //NSSetUncaughtExceptionHandler(&exceptionHandler);
    signal(SIGABRT, signalHandler);
    signal(SIGILL, signalHandler);
    signal(SIGSEGV, signalHandler);
    signal(SIGFPE, signalHandler);
    signal(SIGBUS, signalHandler);
    signal(SIGPIPE, signalHandler);
    return self;
}

- (void) dealloc {
    if (_hist != NULL) {
        history(_hist, &_ev, H_SAVE, historypath);
        NSLog(@"saved REPL command history to: %s", historypath);
        history_end(_hist);
        _hist = NULL;
    }
    el_reset(_el); // make tty sane
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
