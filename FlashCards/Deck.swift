import Cocoa

/// Describes the format of the Deck package. Most save features are not enabled because
/// any operations done to the deck are immediately flushed to disk (without undo).
public class Deck: NSDocument {
    
    /// Internal package Info.plist structure.
    private struct DeckInfo: Codable {
        var uuid: UUID
        var cards: [Card]
        
        public init(uuid: UUID = UUID(), cards: [Card] = []) {
            self.uuid = uuid
            self.cards = cards
        }
    }
    
    /// The internal globally unique Deck ID.
    private var uuid: UUID? = nil
    
    /// The cards contained in the deck (cached in-memory). Any modification to the cards
    /// flushes the memory cache to disk (the Info.plist file in the saved bundle).
    public var cards: [Card] = [] {
        didSet {
            guard !self.isReading else { return }
            let info_ = try? PropertyListEncoder().encode(DeckInfo(uuid: self.uuid!, cards: self.cards))
            let url_ = self.fileURL?.appendingPathComponent("Contents").appendingPathComponent("Info.plist")
            
            guard let info = info_, let url = url_ else { return }
            do {
                try info.write(to: url)
            } catch(let error) {
                DispatchQueue.main.async {
                    self.presentError(error)
                }
            }
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
        
        // Read the Info.plist information.
        let infoURL = url.appendingPathComponent("Contents").appendingPathComponent("Info.plist")
        do {
            let infoData = try Data(contentsOf: infoURL)
            let info = try PropertyListDecoder().decode(DeckInfo.self, from: infoData)
            Swift.print("Unpacked package...")
            
            self.isReading = true
            self.uuid = info.uuid
            self.cards = info.cards
            self.isReading = false
            Swift.print("Package read!")
        } catch(let error) {
            DispatchQueue.main.async {
                self.presentError(error)
                self.close()
            }
        }
    }
    
    public override func writeSafely(to url: URL, ofType typeName: String, for op: NSDocument.SaveOperationType) throws {
        guard op == .saveAsOperation || op == .saveToOperation else { return }
        Swift.print("Writing package...")
        
        // Add Info.plist
        if op == .saveAsOperation || self.uuid == nil {
            self.uuid = UUID() // since we're overwriting the current doc
        }
        let info = try PropertyListEncoder().encode(DeckInfo(uuid: self.uuid!, cards: self.cards))
        Swift.print("Packing package...")
        
        // Save the package wrapper.
        try FileWrapper(directoryWithFileWrappers: [
            "Contents": FileWrapper(directoryWithFileWrappers: [
                "Info.plist": FileWrapper(regularFileWithContents: info)
            ])
        ]).write(to: url, options: [], originalContentsURL: nil)
        try FileManager.default.setAttributes([.extensionHidden : true], ofItemAtPath: url.path)
        Swift.print("Package written!")
        
        // If we already exist and we're save-as/to'ing, then copy all ref'd files too.
        guard self.fileURL != nil else { return }
        let stuff = try FileManager.default.contentsOfDirectory(at: self.fileURL!.appendingPathComponent("Contents"),
                                                                includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for file in stuff where file.lastPathComponent != "Info.plist" {
            try FileManager.default.copyItem(at: file, to: url.appendingPathComponent("Contents").appendingPathComponent(file.lastPathComponent))
        }
    }
    
    // TODO: make modal alerts display as sheets
    /*
    @discardableResult
    public override func presentError(_ error: Error) -> Bool {
        if let window = self.windowForSheet {
            super.presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
            return false // ???
        } else {
            return super.presentError(error)
        }
    }
    */
}
