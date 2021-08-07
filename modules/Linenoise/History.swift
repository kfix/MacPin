/*
 Copyright (c) 2017, Andy Best <andybest.net at gmail dot com>
 Copyright (c) 2010-2014, Salvatore Sanfilippo <antirez at gmail dot com>
 Copyright (c) 2010-2013, Pieter Noordhuis <pcnoordhuis at gmail dot com>
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

internal class History {
    
    public enum HistoryDirection: Int {
        case previous = -1
        case next = 1
    }
    
    var maxLength: UInt = 0 {
        didSet {
            if history.count > maxLength && maxLength > 0 {
                history.removeFirst(history.count - Int(maxLength))
            }
        }
    }
    private var index: Int = 0
    
    var currentIndex: Int {
        return index
    }
    
    private var hasTempItem: Bool = false
    
    private var history: [String] = [String]()
    var historyItems: [String] {
        return history
    }
    
    public func add(_ item: String) {
        // Don't add a duplicate if the last item is equal to this one
        if let lastItem = history.last {
            if lastItem == item {
                // Reset the history pointer to the end index
                index = history.endIndex
                return
            }
        }
        
        // Remove an item if we have reached maximum length
        if maxLength > 0 && history.count >= maxLength {
            _ = history.removeFirst()
        }
        
        history.append(item)
        
        // Reset the history pointer to the end index
        index = history.endIndex
    }

    func replaceCurrent(_ item: String) {
        history[index] = item
    }
    
    // MARK: - History Navigation
    
    internal func navigateHistory(direction: HistoryDirection) -> String? {
        if history.count == 0 {
            return nil
        }
        
        switch direction {
        case .next:
            index += HistoryDirection.next.rawValue
        case .previous:
            index += HistoryDirection.previous.rawValue
        }
        
        // Stop at the beginning and end of history
        if index < 0 {
            index = 0
            return nil
        } else if index >= history.count {
            index = history.count
            return nil
        }
        
        return history[index]
    }
    
    // MARK: - Saving and loading
    
    internal func save(toFile path: String) throws {
        let output = history.joined(separator: "\n")
        try output.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    internal func load(fromFile path: String) throws {
        let input = try String(contentsOfFile: path, encoding: .utf8)
        
        input.split(separator: "\n").forEach {
            add(String($0))
        }
    }
    
}
