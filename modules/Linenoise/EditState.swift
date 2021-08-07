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

internal class EditState {
    var buffer: String = ""
    var location: String.Index
    let prompt: String
    
    public var currentBuffer: String {
        return buffer
    }
    
    init(prompt: String) {
        self.prompt = prompt
        location = buffer.endIndex
    }
    
    var cursorPosition: Int {
        return buffer.distance(from: buffer.startIndex, to: location)
    }
    
    func insertCharacter(_ char: Character) {
        let origLoc = location
        let origEnd = buffer.endIndex
        buffer.insert(char, at: location)
        location = buffer.index(after: location)
        
        if origLoc == origEnd {
            location = buffer.endIndex
        }
    }
    
    func backspace() -> Bool {
        if location != buffer.startIndex {
            if location != buffer.startIndex {
                location = buffer.index(before: location)
            }
            
            buffer.remove(at: location)
            return true
        }
        return false
    }
    
    func moveLeft() -> Bool {
        if location == buffer.startIndex {
            return false
        }
        
        location = buffer.index(before: location)
        return true
    }
    
    func moveRight() -> Bool {
        if location == buffer.endIndex {
            return false
        }
        
        location = buffer.index(after: location)
        return true
    }
    
    func moveHome() -> Bool {
        if location == buffer.startIndex {
            return false
        }
        
        location = buffer.startIndex
        return true
    }
    
    func moveEnd() -> Bool {
        if location == buffer.endIndex {
            return false
        }
        
        location = buffer.endIndex
        return true
    }
    
    func deleteCharacter() -> Bool {
        if location >= currentBuffer.endIndex || currentBuffer.isEmpty {
            return false
        }
        
        buffer.remove(at: location)
        return true
    }
    
    func eraseCharacterRight() -> Bool {
        if buffer.count == 0 || location >= buffer.endIndex {
            return false
        }
        
        buffer.remove(at: location)
        
        if location > buffer.endIndex {
            location = buffer.endIndex
        }
        
        return true
    }
    
    func deletePreviousWord() -> Bool {
        let oldLocation = location
        
        // Go backwards to find the first non space character
        while location > buffer.startIndex && buffer[buffer.index(before: location)] == " " {
            location = buffer.index(before: location)
        }
        
        // Go backwards to find the next space character (start of the word)
        while location > buffer.startIndex && buffer[buffer.index(before: location)] != " " {
            location = buffer.index(before: location)
        }
        
        if buffer.distance(from: oldLocation, to: location) == 0 {
            return false
        }
        
        buffer.removeSubrange(location..<oldLocation)
        
        return true
    }
    
    func deleteToEndOfLine() -> Bool {
        if location == buffer.endIndex || buffer.isEmpty {
            return false
        }
        
        buffer.removeLast(buffer.count - cursorPosition)
        return true
    }
    
    func swapCharacterWithPrevious() -> Bool {
        // Mimic ZSH behavior
        
        if buffer.count < 2 {
            return false
        }
        
        if location == buffer.endIndex {
            // Swap the two previous characters if at end index
            let temp = buffer.remove(at: buffer.index(location, offsetBy: -2))
            buffer.insert(temp, at: buffer.endIndex)
            location = buffer.endIndex
            return true
        } else if location > buffer.startIndex {
            // If the characters are in the middle of the string, swap character under cursor with previous,
            // then move the cursor to the right
            let temp = buffer.remove(at: buffer.index(before: location))
            buffer.insert(temp, at: location)
            
            if location < buffer.endIndex {
                location = buffer.index(after: location)
            }
            return true
        } else if location == buffer.startIndex {
            // If the character is at the start of the string, swap the first two characters, then put the cursor
            // after them
            let temp = buffer.remove(at: location)
            buffer.insert(temp, at: buffer.index(after: location))
            if location < buffer.endIndex {
                location = buffer.index(buffer.startIndex, offsetBy: 2)
            }
            return true
        }
        
        return false
    }
    
    func withTemporaryState(_ body: () throws -> () ) throws {
        let originalBuffer = buffer
        let originalLocation = location
        
        try body()
        
        buffer = originalBuffer
        location = originalLocation
    }
}
