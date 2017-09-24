import Cocoa

/*
Algorithm SM-2 used in the computer-based variant of the SuperMemo method and involving the calculation of easiness factors for particular items:

1. Split the knowledge into smallest possible items.

2. With all items associate an E-Factor equal to 2.5.

3. Repeat items using the following intervals:
I(1):=1
I(2):=6
for n>2: I(n):=I(n-1)*EF
where:
I(n) - inter-repetition interval after the n-th repetition (in days),
EF - E-Factor of a given item
If interval is a fraction, round it up to the nearest integer.
 
4. After each repetition assess the quality of repetition response in 0-5 grade scale:
5 - perfect response
4 - correct response after a hesitation
3 - correct response recalled with serious difficulty
2 - incorrect response; where the correct one seemed easy to recall
1 - incorrect response; the correct one remembered
0 - complete blackout.

5. After each repetition modify the E-Factor of the recently repeated item according to the formula:
EF':=EF+(0.1-(5-q)*(0.08+(5-q)*0.02))
where:
EF' - new value of the E-Factor,
EF - old value of the E-Factor,
q - quality of the response in the 0-5 grade scale.

6. If EF is less than 1.3 then let EF be 1.3.

7. If the quality response was lower than 3 then start repetitions for the item from the beginning without changing the E-Factor (i.e. use intervals I(1), I(2) etc. as if the item was memorized anew).

8. After each repetition session of a given day repeat again all items that scored below four in the quality assessment. Continue the repetitions until all of these items score at least four.
 */

public struct Card: Codable, Hashable, Comparable, Equatable {
    
    public enum Grade: Int, CustomStringConvertible {
        case null, bad, fail, pass, good, bright
        public var description: String {
            switch self {
            case .null:
                return "complete blackout"
            case .bad:
                return "incorrect response; the correct one remembered"
            case .fail:
                return "incorrect response; where the correct one seemed easy to recall"
            case .pass:
                return "correct response recalled with serious difficulty"
            case .good:
                return "correct response after a hesitation"
            case .bright:
                return "perfect response"
            }
        }
    }
    
    /// Default Easiness Factor = default 1.3
    public static var defaultEasinessFactor: Double = 1.3
    
    public var easinessFactor = 2.5
    public var repetition = 0
    public var interval = 0
    
    public var previousDate: TimeInterval = 0 /* @init: never reviewed before */
    public var nextDate = Date().timeIntervalSince1970
    
    public let uuid: UUID
    public let frontURL: URL
    public let backURL: URL
    
    /// The front face of the card. Can be an image or a string.
    public var front: Any? {
        if self.frontURL.pathExtension == "png" || self.frontURL.pathExtension == "jpg" {
            return NSImage(byReferencing: self.frontURL)
        } else if self.frontURL.pathExtension == "rtf" || self.frontURL.pathExtension == "txt" {
            return try? NSAttributedString(url: self.frontURL, options: [:], documentAttributes: nil)
        }
        return nil
    }
    
    /// The back face of the card. Can be an image or a string.
    public var back: Any? {
        if self.backURL.pathExtension == "png" || self.backURL.pathExtension == "jpg" {
            return NSImage(byReferencing: self.backURL)
        } else if self.backURL.pathExtension == "rtf" || self.backURL.pathExtension == "txt" {
            return try? NSAttributedString(url: self.backURL, options: [:], documentAttributes: nil)
        }
        return nil
    }
    
    public init(id: UUID = UUID(), front frontURL: URL, back backURL: URL) {
        self.uuid = id
        self.frontURL = frontURL
        self.backURL = backURL
    }
    
    /// Match a front face to a back face for a card.
    /// Automatically interpolate from the front URL the back URL if possible.
    /// Note: this assumes the naming is *.front.* and *.back.* for the card face URLs.
    internal init(front frontURL: URL) throws {
        let pc = frontURL.lastPathComponent.replacingOccurrences(of: ".front.", with: ".back.")
        let backURL = frontURL.deletingLastPathComponent().appendingPathComponent(pc)
        if !(try backURL.checkResourceIsReachable()) {
            throw CocoaError(.fileNoSuchFile)
        }
        self.init(front: frontURL, back: backURL)
    }
}

public extension Card {
    
    public mutating func grade(_ grade: Grade) {
        let cardGrade = grade.rawValue
        if cardGrade < 3 {
            self.repetition = 0
            self.interval = 0
        } else {
            let qualityFactor = Double(Grade.bright.rawValue - cardGrade)
            let newEasinessFactor = self.easinessFactor + (0.1 - qualityFactor * (0.08 + qualityFactor * 0.02))
            if newEasinessFactor < Card.defaultEasinessFactor {
                self.easinessFactor = Card.defaultEasinessFactor
            } else {
                self.easinessFactor = newEasinessFactor
            }
            self.repetition += 1
            switch self.repetition {
            case 1:
                self.interval = 1
                break
            case 2:
                self.interval = 6
                break
            default:
                let newInterval = ceil(Double(self.repetition - 1) * self.easinessFactor)
                self.interval = Int(newInterval)
            }
        }
        
        if cardGrade == 3 {
            self.interval = 0
        }
        
        let newNextDatetime = Date().timeIntervalSince1970 + Double(self.interval * (60 * 60 * 24))
        self.previousDate = self.nextDate
        self.nextDate = newNextDatetime
    }
}

public extension Card {
    public var hashValue: Int {
        return self.frontURL.hashValue &+ self.backURL.hashValue
    }
    
    public static func <(lhs: Card, rhs: Card) -> Bool {
        return lhs.nextDate < rhs.nextDate
    }
    
    public static func ==(lhs: Card, rhs: Card) -> Bool {
        return (lhs.frontURL == rhs.frontURL && lhs.backURL == rhs.backURL)
    }
}
