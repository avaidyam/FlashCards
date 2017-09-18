import Cocoa

public struct Deck {
    
    /// Get all decks (really just folders with images) in the default directory.
    public static var all: [Deck] {
        let docs = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        let decks = docs[0].appendingPathComponent("Decks", isDirectory: true)
        let urls = try? FileManager.default.contentsOfDirectory(at: decks,
                                                                includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        return (urls ?? []).map { Deck($0) }
    }
    
    /// Get all the cards (image pairs) in a deck.
    public var cards: [Card] {
        let urls = try? FileManager.default.contentsOfDirectory(at: self.url,
                                                                includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
        return (urls ?? []).filter { $0.lastPathComponent.contains(".front.") }.flatMap { try? Card(front: $0) }
    }
    
    public let url: URL
    
    fileprivate init(_ url: URL) {
        self.url = url
    }
}

public struct Card {
    
    /// The front face of the card. Can be an image or a string.
    public var front: NSImage {
        return NSImage(byReferencing: self.frontURL)
    }
    
    /// The back face of the card. Can be an image or a string.
    public var back: NSImage {
        return NSImage(byReferencing: self.backURL)
    }
    
    public let frontURL: URL
    public let backURL: URL
    
    /// Match a front face to a back face for a card.
    fileprivate init(front frontURL: URL) throws {
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
