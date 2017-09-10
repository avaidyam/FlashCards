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
    
    @IBAction func addCard(_ sender: NSButton!) {
        
        // Alert user to select a Deck first.
        guard self.currentDeckIdx >= 0 && self.currentDeckIdx < self.allDecks.count else {
            let alert = NSAlert()
            alert.messageText = "No deck selected or available."
            alert.informativeText = "You need to select a deck before adding a card to it."
            alert.beginSheetModal(for: self.window!)
            return
        }
        
        // Hide the window, take the screenshot, and show the window afterwards!
        self.window?.orderOut(nil)
        DispatchQueue.main.async {
            let img = try? screenshot()
            self.imageController?.imageView.image = img
            DispatchQueue.main.async {
                self.window?.makeKeyAndOrderFront(nil)
            }
        }
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

/*
public class Deck {
    public static var all: [Deck] = []
    public var cards: [Card] = []
}

public class Card {
    public var front: NSImage
    public var back: NSImage
}
*/

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

// Take a screenshot using the system function and provide it as an image.
func screenshot() throws -> NSImage {
    let task = Process()
    task.launchPath = "/usr/sbin/screencapture"
    task.arguments = ["-cio"]
    task.launch()
    
    var img: NSImage? = nil
    let s = DispatchSemaphore(value: 0)
    task.terminationHandler = { _ in
        guard let pb = NSPasteboard.general.pasteboardItems?.first, pb.types.contains(.png) else {
            s.signal(); return
        }
        guard let data = pb.data(forType: .png), let image = NSImage(data: data) else {
            s.signal(); return
        }
        img = image
        NSPasteboard.general.clearContents()
        s.signal()
    }
    s.wait()
    
    guard img != nil else { throw CocoaError(.fileNoSuchFile) }
    return img!
}
