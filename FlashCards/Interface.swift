import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let a = NSAlert()
        a.messageText = "Opening \(filename)..."
        a.runModal()
        return true
    }
}

// This is where most of the deck/card management is.
public class WindowController: NSWindowController {
    
    private var presentingDeck: Deck? = nil {
        didSet {
            self.presentingCard = self.presentingDeck?.cards.first
        }
    }
    private var presentingCard: Card? = nil {
        didSet {
            self.faceFront = true
        }
    }
    
    // Swap the visible face of the current card of the current deck.
    private var faceFront: Bool = true {
        didSet {
            if let card = self.presentingCard {
                self.faceViewController?.representedObject =  self.faceFront ? card.front : card.back
            } else {
                self.faceViewController?.representedObject = nil
            }
        }
    }
    
    private var faceViewController: FaceViewController? {
        return self.contentViewController as? FaceViewController
    }
    
    public override func windowDidLoad() {
        self.window?.titleVisibility = .hidden
    }
    
    // Select a new deck to present.
    @IBAction public func select(_ sender: NSButton!) {
        let menu = NSMenu(title: "Decks")
        Deck.all.forEach {
            let i = menu.addItem(withTitle: $0.url.lastPathComponent, action: #selector(self.choose(_:)), keyEquivalent: "")
            i.representedObject = $0
        }
        if menu.items.count == 0 {
            menu.addItem(withTitle: "No Decks Imported", action: nil, keyEquivalent: "")
        }
        menu.popUp(positioning: menu.items[0], at: NSPoint(x: 0, y: sender.frame.height), in: sender)
    }
    
    // Choose a new deck from the selection list.
    @IBAction public func choose(_ sender: NSMenuItem!) {
        self.presentingDeck = sender.representedObject as? Deck
    }
    
    @IBAction public func addCard(_ sender: NSButton!) {
        
        // Alert user to select a Deck first.
        guard self.presentingDeck == nil else {
            let alert = NSAlert()
            alert.messageText = "No deck selected or available."
            alert.informativeText = "You need to select a deck before adding a card to it."
            alert.beginSheetModal(for: self.window!)
            return
        }
        
        // Hide the window, take the screenshot, and show the window afterwards!
        self.window?.orderOut(nil)
        DispatchQueue.global(qos: .userInteractive).async {
            let img = try? NSScreen.screenshot()
            self.faceViewController?.representedObject = img
            let marked = try? img!.markup(in: self.faceViewController!.view)
            self.faceViewController?.representedObject = marked
            
            try? img?.write(to: URL(fileURLWithPath: "/Users/aditya/Desktop/Card Front \(Date()).png"), type: .png)
            try? marked?.write(to: URL(fileURLWithPath: "/Users/aditya/Desktop/Card Back \(Date()).png"), type: .png)
            
            DispatchQueue.main.async {
                self.window?.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    // Flip the current card.
    @IBAction public func flip(_ sender: NSButton!) {
        self.faceFront = !self.faceFront
    }
    
    // Show the previous card in the deck and wrap around if at the start.
    @IBAction public func prev(_ sender: NSButton!) {
        guard let deck = self.presentingDeck, let card = self.presentingCard else { return }
        let nextIdx = deck.cards.index { $0.frontURL == card.frontURL }?.advanced(by: -1) ?? 0
        self.presentingCard = deck.cards[safe: nextIdx] ?? deck.cards.last
    }
    
    // Show the next card in the deck and wrap around if at the end.
    @IBAction public func next(_ sender: NSButton!) {
        guard let deck = self.presentingDeck, let card = self.presentingCard else { return }
        let nextIdx = deck.cards.index { $0.frontURL == card.frontURL }?.advanced(by: +1) ?? 0
        self.presentingCard = deck.cards[safe: nextIdx] ?? deck.cards.first
    }
}

public class FaceViewController: NSViewController {
    @IBOutlet private var imageView: NSImageView! = nil
    @IBOutlet private var textView: NSTextView! = nil
    @IBOutlet private var noneLabel: NSTextField! = nil
    
    public override func viewDidAppear() {
        self.representedObject = nil
    }
    
    // Toggle between the image view and text view based on the represented object type.
    public override var representedObject: Any? {
        didSet {
            DispatchQueue.main.async {
                if let rep = self.representedObject as? String {
                    self.imageView.isHidden = true
                    self.textView.isHidden = false
                    self.noneLabel.isHidden = true
                    
                    self.imageView.image = nil
                    self.textView.textStorage?.setAttributedString(NSAttributedString(string: rep))
                } else if let rep = self.representedObject as? NSAttributedString {
                    self.imageView.isHidden = true
                    self.textView.isHidden = false
                    self.noneLabel.isHidden = true
                    
                    self.imageView.image = nil
                    self.textView.textStorage?.setAttributedString(rep)
                } else if let rep = self.representedObject as? NSImage {
                    self.imageView.isHidden = false
                    self.textView.isHidden = true
                    self.noneLabel.isHidden = true
                    
                    self.imageView.image = rep
                    self.textView.textStorage?.setAttributedString(NSAttributedString())
                } else {
                    self.imageView.isHidden = true
                    self.textView.isHidden = true
                    self.noneLabel.isHidden = false
                    
                    self.imageView.image = nil
                    self.textView.textStorage?.setAttributedString(NSAttributedString())
                }
            }
        }
    }
}

public class DeckListController: NSViewController, NSBrowserDelegate {
    
    @IBOutlet var header: NSViewController?
    @IBOutlet var preview: NSViewController?
    
    public func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return Deck.all.count
        } else {
            return (item as! Deck).cards.count
        }
    }
    
    public func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return Deck.all[index]
        } else {
            return (item as! Deck).cards[index]
        }
    }
    
    public func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        return (item is Card)
    }
    
    public func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        if let item = item as? Deck {
            return item.url.lastPathComponent
        } else if let item = item as? Card {
            return item.frontURL.lastPathComponent.components(separatedBy: ".").first ?? "card"
        }
        return "???"
    }
    
    public func browser(_ browser: NSBrowser, headerViewControllerForItem item: Any?) -> NSViewController? {
        print("HEADER", item)
        return self.header
    }
    
    public func browser(_ browser: NSBrowser, previewViewControllerForLeafItem item: Any) -> NSViewController? {
        print("PREVIEW", item)
        return self.preview
    }
}

