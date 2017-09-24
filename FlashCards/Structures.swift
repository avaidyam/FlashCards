import Cocoa

public struct Card: Equatable {
    
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
    
    public static func ==(lhs: Card, rhs: Card) -> Bool {
        return (lhs.frontURL == rhs.frontURL && lhs.backURL == rhs.backURL)
    }
}

public class DeckDocument: NSDocument {
    
    /// The internal Deck itself.
    private var deck: URL? = nil
    
    /// Get all the cards (image pairs) in a deck.
    public var cards: [Card] {
        guard let url = self.deck else { return [] }
        let urls = try? FileManager.default.contentsOfDirectory(at: url.appendingPathComponent("Contents"),
                                                                includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
        return (urls ?? []).filter { $0.lastPathComponent.contains(".front.") }.flatMap { try? Card(front: $0) }
    }
    
    public override init() {
        super.init()
        
        // If this is an untitled document, mark it dirty and force a save.
        DispatchQueue.main.async {
            if self.fileURL == nil {
                self.updateChangeCount(.changeDone)
                self.save(withDelegate: self,
                          didSave: #selector(self.document(_:didSave:contextInfo:)),
                          contextInfo: nil)
            }
        }
    }
    
    // Disable autosave.
    public override var autosavingFileType: String? {
        return nil
    }
    
    // Disable versions.
    public override class var preservesVersions: Bool {
        return false
    }
    
    // Disable cloud storage.
    public override class var usesUbiquitousStorage: Bool {
        return false
    }
    
    // Enable multithreading.
    public override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        return true
    }
    
    // Load from storyboard instead of a nib.
    public override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("DeckWindowController")) as! DeckWindowController
        self.addWindowController(windowController)
    }
    
    // Ensure we saved, or die if not (this is only invoked on start for untitled docs).
    @objc public func document(_ doc: NSDocument, didSave: Bool, contextInfo: Any?) {
        guard doc == self, contextInfo == nil else { return }
        guard didSave else { self.close(); return }
        self.changeCountToken(for: .saveAsOperation)
    }
    
    public override func read(from url: URL, ofType typeName: String) throws {
        Swift.print("Reading package...")
        self.deck = url
    }
    
    public override func writeSafely(to url: URL, ofType typeName: String, for op: NSDocument.SaveOperationType) throws {
        guard op == .saveAsOperation || op == .saveToOperation else { return }
        Swift.print("Writing package...")
        
        // Get all the existing cards if needed.
        var fws = [String: FileWrapper]()
        for card in self.cards {
            if  let front = try? FileWrapper(url: card.frontURL, options: .immediate),
                let back = try? FileWrapper(url: card.backURL, options: .immediate) {
                fws[card.frontURL.lastPathComponent] = front
                fws[card.backURL.lastPathComponent] = back
            }
        }
        
        // Save the package wrapper.
        try FileWrapper(directoryWithFileWrappers: [
            "Contents": FileWrapper(directoryWithFileWrappers: fws)
        ]).write(to: url, options: [], originalContentsURL: nil)
        
        // If this is a first-time-save or a save-as, load the deck.
        if self.deck == nil || op == .saveAsOperation {
            self.deck = url
        }
    }
}
