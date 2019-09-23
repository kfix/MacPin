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
//	http://cvsweb.netbsd.org/bsdweb.cgi/src/lib/libedit
//  http://thrysoee.dk/editline/

#include <termios.h>

const char * el_prompt = "> " ;
const char* prompter(EditLine *e) {
	// TODO: reposition prompt reprintings https://stackoverflow.com/a/35190285/3878712
	// http://ballingt.com/rich-terminal-applications/
	//el_reset(e);
	//el_set(e, EL_REFRESH);

	// add some colors?
	// https://stackoverflow.com/questions/21240181/how-to-colorize-the-prompt-of-an-editline-application
	// 	http://gnats.netbsd.org/47539 https://issues.asterisk.org/jira/browse/ASTERISK-25587
	//	https://github.com/cdesjardins/libedit/blob/master/examples/fileman.c

	//el_beep(e); // boop!
    return el_prompt;
}
const char * historypath;

struct termios ttyopts; // are these sane by default?

void exceptionHandler(NSException *exception) {
    // app crashed mid-prompt, so lets restore the term
    tcsetattr(1, TCSANOW, &ttyopts);
    tcflush(1, TCIOFLUSH);
    return;
}

void signalHandler(int sig) {
    // app crashed mid-prompt, so lets restore the term
	//term.c_oflag &= ~ECHO // `stty echo`
	// howto `stty sane` ??
    //el_reset(_el); // make tty sane
   	/* Use defaults of <sys/ttydefaults.h> for base settings */
   	// https://github.com/freebsd/freebsd/blob/master/sys/sys/ttydefaults.h
   	// https://opensource.apple.com/source/xnu/xnu-344.49/bsd/sys/ttydefaults.h.auto.html
   	// https://github.com/freebsd/freebsd/blob/master/bin/stty/key.c#L258
	ttyopts.c_iflag |= TTYDEF_IFLAG; // input modes
	//ttyopts.c_iflag |= (BRKINT | ICRNL | IMAXBEL);
	ttyopts.c_oflag |= TTYDEF_OFLAG; // output modes
	ttyopts.c_lflag = TTYDEF_LFLAG | (ECHOKE|ECHOE|ECHOK|ECHOPRT|ECHOCTL|ALTWERASE|TOSTOP|NOFLSH); // local modes
	ttyopts.c_cflag |= TTYDEF_CFLAG; // control modes
    tcsetattr(1, TCSANOW, &ttyopts); // TCSADRAIN, TCSAFLUSH
    // el_set(el, EL_SETTY, "-d", "-isig", NULL);
    tcflush(1, TCIOFLUSH);
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
        ttyopts.c_lflag &= ~ISIG; // pass control seqs to app instead of signalling
        tcsetattr(1, TCSANOW, &ttyopts);

        historypath = [[NSTemporaryDirectory() stringByAppendingString:@".REPL_history"] UTF8String];
        el_prompt = [[NSString stringWithFormat:@"<%s> %@", argv0, prompt] UTF8String];
        // Setup the editor
        _el = el_init(argv0, stdin, stdout, stderr); // argv0 designates the .editrc app-name cfgs to use
        el_set(_el, EL_PROMPT, &prompter);
        el_set(_el, EL_EDITOR, "emacs");
        el_source(_el, NULL); // try $PWD, then $HOME's .editrc

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
    //el_set(_el, EL_SIGNAL, 1); // let libedit handle quit signals and el_reset
    // quitters:  SIGCONT , SIGHUP , SIGINT , SIGQUIT , SIGSTOP , SIGTERM , SIGTSTP , and SIGWINCH

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
    tcflush(1, TCIOFLUSH);
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
