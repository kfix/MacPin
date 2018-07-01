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

struct termios ttyopts; // are these sane by default?

void exceptionHandler(NSException *exception) {
    // app crashed mid-prompt, so lets restore the term
    tcsetattr(1, TCSANOW, &ttyopts);
    return;
}

void signalHandler(int sig) {
    // app crashed mid-prompt, so lets restore the term
	//term.c_oflag &= ~ECHO // `stty echo`
	// howto `stty sane` ??
    //el_reset(_el); // make tty sane
   	/* Use defaults of <sys/ttydefaults.h> for base settings */
   	// https://github.com/freebsd/freebsd/blob/master/sys/sys/ttydefaults.h
   	// https://github.com/freebsd/freebsd/blob/master/bin/stty/key.c#L258
	ttyopts.c_iflag |= TTYDEF_IFLAG; // input
	//ttyopts.c_iflag |= (BRKINT | ICRNL | IMAXBEL);
	ttyopts.c_oflag |= TTYDEF_OFLAG; // output
	//ttyopts.c_lflag |= TTYDEF_LFLAG; // local
	ttyopts.c_lflag = TTYDEF_LFLAG | (ECHOKE|ECHOE|ECHOK|ECHOPRT|ECHOCTL|ALTWERASE|TOSTOP|NOFLSH);
	ttyopts.c_cflag |= TTYDEF_CFLAG; // control
    tcsetattr(1, TCSANOW, &ttyopts); // TCSADRAIN, TCSAFLUSH
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
    signal(SIGABRT, signalHandler);	// BPT/Trap NSException
    signal(SIGILL, signalHandler);
    signal(SIGSEGV, signalHandler);	// EXC_BAD_ACCESS
    signal(SIGFPE, signalHandler);	// EXC_BAD_ACCESS
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
    NSString *nline;
    NSCharacterSet *blanks = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    const char* line = el_gets(_el, &count);

    if (count > 0) {
        nline = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
        if ([[nline stringByTrimmingCharactersInSet: blanks] length] > 0)
            history(_hist, &_ev, H_ENTER, line); // push into history
        return nline;
    }

    return nil;
}
@end
