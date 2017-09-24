import Cocoa

public struct Deck {
    
    /// Get all decks (really just folders with images) in the default directory.
    public static var all: [Deck] {
        return []
    }
    
    /// Get all the cards (image pairs) in a deck.
    public var cards: [Card] {
        let urls = try? FileManager.default.contentsOfDirectory(at: self.url.appendingPathComponent("Contents"),
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

public class DeckDocument: NSDocument {
    
    private var deck: Deck? = nil
    
    public override init() {
        super.init()
        Swift.print(self.fileURL)
        self.updateChangeCount(.changeDone)
    }
    
    public override class var autosavesInPlace: Bool {
        return true
    }
    
    public override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        return true
    }
    
    /*
    public override var displayName: String! {
        get {
            return self.deck?.url.lastPathComponent.components(separatedBy: ".").first ?? "Untitled"
        }
        set {}
    }*/
    
    public override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("DeckWindowController")) as! DeckWindowController
        windowController.presentingDeck = self.deck
        self.addWindowController(windowController)
    }
    
    public override func read(from url: URL, ofType typeName: String) throws {
        self.deck = Deck(url)
    }
    
    public override func writeSafely(to url: URL, ofType typeName: String, for op: NSDocument.SaveOperationType) throws {
        guard op == .saveAsOperation || op == .saveToOperation else { return }
        Swift.print("Writing package...")
        
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            "Contents": FileWrapper(directoryWithFileWrappers: [
                ://"": ""
            ])
        ])
        try wrapper.write(to: url, options: [], originalContentsURL: nil)
        
        // If this is a first-time save, cache our deck.
        if self.deck == nil {
            self.deck = Deck(url)
        }
    }
}
