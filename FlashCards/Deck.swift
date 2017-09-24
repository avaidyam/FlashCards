import Cocoa

/// Describes the format of the Deck package. Most save features are not enabled because
/// any operations done to the deck are immediately flushed to disk (without undo).
public class Deck: NSDocument {
    
    /// The internal Deck itself.
    private var deck: URL? = nil
    
    /// The cards contained in the deck (cached in-memory). Any modification to the cards
    /// flushes the memory cache to disk (the Info.plist file in the saved bundle).
    public var cards: [Card] = [] {
        didSet {
            guard !self.isReading else { return }
            let info_ = try? PropertyListEncoder().encode(self.cards)
            let url_ = self.deck?.appendingPathComponent("Contents").appendingPathComponent("Info.plist")
            
            guard let info = info_, let url = url_ else { return }
            try? info.write(to: url)
        }
    }
    
    // Internal reading lock to prevent re-saving a just-read-and-loaded file.
    private var isReading: Bool = false
    
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
    
    // Disable autosave, versions, and cloud storage. Enable multithreading.
    public override var autosavingFileType: String? { return nil }
    public override class var preservesVersions: Bool { return false }
    public override class var usesUbiquitousStorage: Bool { return false }
    public override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { return true }
    
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
        
        // Read the Info.plist information.
        let infoURL = url.appendingPathComponent("Contents").appendingPathComponent("Info.plist")
        if let infoData = try? Data(contentsOf: infoURL), let info = try? PropertyListDecoder().decode([Card].self, from: infoData) {
            self.isReading = true
            self.cards = info
            self.isReading = false
        } else {
            self.cards = [] // this package didn't have an Info.plist!
        }
    }
    
    public override func writeSafely(to url: URL, ofType typeName: String, for op: NSDocument.SaveOperationType) throws {
        guard op == .saveAsOperation || op == .saveToOperation else { return }
        Swift.print("Writing package...")
        
        // Add Info.plist
        let info = try PropertyListEncoder().encode(self.cards)
        
        // Save the package wrapper.
        try FileWrapper(directoryWithFileWrappers: [
            "Contents": FileWrapper(directoryWithFileWrappers: [
                "Info.plist": FileWrapper(regularFileWithContents: info)
            ])
        ]).write(to: url, options: [], originalContentsURL: nil)
        
        // If this is a first-time-save or a save-as, load the deck.
        if self.deck == nil || op == .saveAsOperation {
            self.deck = url
        }
    }
}
