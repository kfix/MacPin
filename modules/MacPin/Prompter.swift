import Dispatch
import Linenoise

class Prompter {
	var running = false
	var prompter: DispatchWorkItem? = nil
	var aborter: DispatchWorkItem? = nil

	required init(_ worker: DispatchWorkItem?) {
		prompter = worker
	}

	func start() {
		guard let prompter = prompter, running == false else { return }
		DispatchQueue.global(qos: .userInteractive).async(execute: prompter)
		self.running = true

		if let aborter = aborter {
			prompter.notify(queue: .main, execute: aborter)
			aborter.notify(queue: .main) {
				self.running = false
			}
		}
	}

	func wait() {
		guard let prompter = prompter, running == false else { return }
		prompter.wait()
	}

	// TODO: exposing a websocketREPL would also be neat: https://github.com/siuying/IGJavaScriptConsole https://github.com/zwopple/PocketSocket
	class func termiosREPL(_ eval:((String)->Void)? = nil, ps1: StaticString = #file, ps2: StaticString = #function, abort:(()->(()->Void)?)? = nil) -> Prompter? {
	#if arch(x86_64) || arch(i386)
		var final: (()->Void)? = nil
		let prompter = DispatchWorkItem {

			var done = false
			let prompt = "<\(CommandLine.arguments[0])> % "
			let ln = LineNoise()

			while (!done) {
				do {
					let line = try ln.getLine(prompt: prompt) // R: blocks here until Enter pressed
					if !line.hasPrefix("\n") {
						//print("| ") // result prefix
						print() //newline
						DispatchQueue.main.sync {
							// JS can mutate native UI objects that are not BG-thread-safe
							eval?(line) // E:, P:
						}
					}
				} catch LinenoiseError.EOF {
					// stdin closed, CTRL-C'd or EOF'd
					if abort == nil { print("\(ps1): got EOF from stdin, stopping \(ps2)") }
					done = true
				} catch {
					print(error)
				}
				// L: command dispatched, restart loop
			}
		}

		var inst = Prompter(prompter)
		if let abort = abort, let final = abort() {
			inst.aborter = DispatchWorkItem { final() }
		}
		return inst
	#else
		print("TTY Prompter() not available on this device.")
		return nil
	#endif
	}
}
