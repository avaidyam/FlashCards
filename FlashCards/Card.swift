import Cocoa

public class Card: Equatable, Hashable {
    
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
    
    public var repetition = 0
    public var interval = 0
    public var easinessFactor = 2.5
    public var previousDate = Date().timeIntervalSince1970
    public var nextDate = Date().timeIntervalSince1970
    
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
    
    public let frontURL: URL
    public let backURL: URL
    
    /// Match a front face to a back face for a card.
    internal init(front frontURL: URL) throws {
        self.frontURL = frontURL
        
        // Automatically interpolate from the front URL the back URL if possible.
        // Note: this assumes the naming is *.front.* and *.back.* for the card face URLs.
        let pc = self.frontURL.lastPathComponent.replacingOccurrences(of: ".front.", with: ".back.")
        let back = self.frontURL.deletingLastPathComponent().appendingPathComponent(pc)
        if !(try back.checkResourceIsReachable()) {
            throw CocoaError(.fileNoSuchFile)
        }
        
        self.backURL = back
    }
}

public extension Card {
    
    /// Grade Flash card
    ///
    /// - Parameters:
    ///   - flashcard: Flashcard
    ///   - grade: Grade(0-5)
    ///   - currentDatetime: TimeInterval
    public func grade(_ grade: Grade, currentDatetime: TimeInterval) {
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
        let seconds = 60
        let minutes = 60
        let hours = 24
        let dayMultiplier = seconds * minutes * hours
        let extraDays = dayMultiplier * self.interval
        let newNextDatetime = currentDatetime + Double(extraDays)
        self.previousDate = self.nextDate
        self.nextDate = newNextDatetime
    }
}

public extension Card {
    public var hashValue: Int {
        return self.frontURL.hashValue &+ self.backURL.hashValue
    }
    
    public static func ==(lhs: Card, rhs: Card) -> Bool {
        return (lhs.frontURL == rhs.frontURL && lhs.backURL == rhs.backURL)
    }
}
