import Cocoa

public class GradingEngine {
    
    public enum Grade: Int, CustomStringConvertible {
        
        /// complete blackout.
        case null
        /// incorrect response; the correct one remembered
        case bad
        /// incorrect response; where the correct one seemed easy to recall
        case fail
        /// correct response recalled with serious difficulty
        case pass
        /// correct response after a hesitation
        case good
        /// perfect response
        case bright
        
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
    
    /// Easiness Factor; The default value is 1.3
    var easinessFactor: Double
    
    public init(easinessFactor: Double = 1.3) {
        self.easinessFactor = easinessFactor
    }
    
    /// Grade Flash card
    ///
    /// - Parameters:
    ///   - flashcard: Flashcard
    ///   - grade: Grade(0-5)
    ///   - currentDatetime: TimeInterval
    /// - Returns: Flashcard with new interval and repetition
    public func grade(flashcard: Flashcard, grade: Grade, currentDatetime: TimeInterval) -> Flashcard {
        let cardGrade = grade.rawValue
        if cardGrade < 3 {
            flashcard.repetition = 0
            flashcard.interval = 0
        } else {
            let qualityFactor = Double(Grade.bright.rawValue - cardGrade)
            let newEasinessFactor = flashcard.easinessFactor + (0.1 - qualityFactor * (0.08 + qualityFactor * 0.02))
            if newEasinessFactor < easinessFactor {
                flashcard.easinessFactor = easinessFactor
            } else {
                flashcard.easinessFactor = newEasinessFactor
            }
            flashcard.repetition += 1
            switch flashcard.repetition {
            case 1:
                flashcard.interval = 1
                break
            case 2:
                flashcard.interval = 6
                break
            default:
                let newInterval = ceil(Double(flashcard.repetition - 1) * flashcard.easinessFactor)
                flashcard.interval = Int(newInterval)
            }
        }
        if cardGrade == 3 {
            flashcard.interval = 0
        }
        let seconds = 60
        let minutes = 60
        let hours = 24
        let dayMultiplier = seconds * minutes * hours
        let extraDays = dayMultiplier * flashcard.interval
        let newNextDatetime = currentDatetime + Double(extraDays)
        flashcard.previousDate = flashcard.nextDate
        flashcard.nextDate = newNextDatetime
        return flashcard
    }
}

/// Flashcard
public class Flashcard: Equatable, Hashable {
    public var front: String
    public var back: String
    
    public var uuid: UUID
    
    public var repetition = 0
    public var interval = 0
    public var easinessFactor = 2.5
    public var previousDate = Date().timeIntervalSince1970
    public var nextDate = Date().timeIntervalSince1970
    
    public init(front: String, back: String) {
        self.uuid = UUID()
        self.front = front
        self.back = back
    }
}

public extension Flashcard {
    public var hashValue: Int {
        return uuid.hashValue
    }
    
    public static func == (lhs: Flashcard, rhs: Flashcard) -> Bool {
        return lhs.uuid == rhs.uuid &&
            lhs.front == rhs.front &&
            lhs.back == rhs.back
    }
}
