import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {}
class ImageViewController: NSViewController {
    var imageView: NSImageView {
        return self.view as! NSImageView
    }
}

// This is where most of the deck/card management is.
class WindowController: NSWindowController {
    
    private var allDecks: [URL] = []
    private var allCards: [(URL, URL)] = []
    
    // Set the currently used deck. Note: resets the current card.
    private var currentDeckIdx = 0 {
        didSet {
            if self.currentDeckIdx < 0 || self.currentDeckIdx >= self.allDecks.count {
                self.currentDeckIdx = 0
            }
            self.currentCardIdx = 0
        }
    }
    
    // Set the currently displayed card. Note: resets the visible face.
    private var currentCardIdx = 0 {
        didSet {
            if self.currentCardIdx < 0 || self.currentCardIdx >= self.allCards.count {
                self.currentCardIdx = 0
            }
            self.faceFront = true
        }
    }
    
    // Swap the visible face of the current card of the current deck.
    private var faceFront: Bool = true {
        didSet {
            let card = self.allCards[self.currentCardIdx]
            self.imageController?.imageView.image = NSImage(byReferencing: self.faceFront ? card.0 : card.1)
        }
    }
    
    var imageController: ImageViewController? {
        return self.contentViewController as? ImageViewController
    }
    
    override func windowDidLoad() {
        self.window?.titleVisibility = .hidden
    }
    
    // Select a new deck to present.
    @IBAction func select(_ sender: NSButton!) {
        guard let decks = try? decks() else { return }
        self.allDecks = decks
        
        let menu = NSMenu(title: "Decks")
        decks.enumerated().forEach {
            let (idx, url) = $0
            let i = menu.addItem(withTitle: url.lastPathComponent, action: #selector(self.choose(_:)), keyEquivalent: "")
            i.tag = idx
        }
        menu.popUp(positioning: menu.items[0], at: NSPoint(x: 0, y: sender.frame.height), in: sender)
    }
    
    // Choose a new deck from the selection list.
    @IBAction func choose(_ sender: NSMenuItem!) {
        guard let urls = try? cards(in: self.allDecks[self.currentDeckIdx]) else { return }
        
        // Iterate all the front card images to index back card images too.
        self.allCards = []
        for url in urls {
            if url.lastPathComponent.contains(".front.") {
                guard let splat = try? pair(from: url) else { continue }
                self.allCards.append(splat)
            }
        }
        
        self.currentDeckIdx = sender.tag
    }
    
    // Flip the current card.
    @IBAction func flip(_ sender: NSButton!) {
        self.faceFront = !self.faceFront
    }
    
    // Show the previous card in the deck.
    @IBAction func prev(_ sender: NSButton!) {
        self.currentCardIdx -= 1
    }
    
    // Show the next card in the deck.
    @IBAction func next(_ sender: NSButton!) {
        self.currentCardIdx += 1
    }
}

// Get all decks (really just folders with images) in the default directory.
func decks() throws -> [URL] {
    let docs = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
    let decks = docs[0].appendingPathComponent("Decks", isDirectory: true)
    return try FileManager.default.contentsOfDirectory(at: decks, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
}

// Get all the cards (image pairs) in a deck.
func cards(in deck: URL) throws -> [URL] {
    return try FileManager.default.contentsOfDirectory(at: deck, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
}

// Match a front face to a back face for a card.
func pair(from face: URL) throws -> (URL, URL) {
    let pc = face.lastPathComponent.replacingOccurrences(of: ".front.", with: ".back.")
    let back = face.deletingLastPathComponent().appendingPathComponent(pc)
    if !(try back.checkResourceIsReachable()) {
        throw CocoaError(.fileNoSuchFile)
    }
    return (face, back)
}
