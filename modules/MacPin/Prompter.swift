import Dispatch
import Linenoise
import Foundation

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
	class func termiosREPL(_ eval:((String)->Void)? = nil, ps1: StaticString = #file, ps2: StaticString = #function, abort:(()->(()->Void)?)? = nil) -> Prompter {
		var final: (()->Void)? = nil
		let prompter = DispatchWorkItem {

			var done = false
			let prompt = "<\(CommandLine.arguments[0])> % "
			let ln = LineNoise(outputFile: FileHandle.standardError.fileDescriptor)

			while (!done) {
				do {
					let line = try ln.getLine(prompt: prompt) // R: blocks here until Enter pressed
					if !line.hasPrefix("\n") {
						//print("| ") // result prefix
						ln.addHistory(line)
						g_stdErr.write("\n")
						DispatchQueue.main.sync {
							// JS can mutate native UI objects that are not BG-thread-safe
							eval?(line) // E:, P:
						}
					}
				} catch LinenoiseError.EOF {
					// stdin closed or EOF'd
					if abort == nil { g_stdErr.write("\(ps1): got closed from stdin, stopping \(ps2)") }
					done = true
				} catch LinenoiseError.CTRL_C {
					// stdin CTRL-C'd
					if abort == nil { g_stdErr.write("\(ps1): got closed from stdin, stopping \(ps2)") }
					done = true
				} catch {
					g_stdErr.write(error.localizedDescription + "\n")
					done = true // best to just stop
				}
				// L: command dispatched, restart loop
			}
		}

		var inst = Prompter(prompter)
		if let abort = abort, let final = abort() {
			inst.aborter = DispatchWorkItem { final() }
		}
		return inst
	}
}
