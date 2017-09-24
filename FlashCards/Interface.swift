import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }
    
    /// Add an opened deck to the saved deck list.
    public func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        NSDocumentController.shared.openDocument(withContentsOf: URL(fileURLWithPath: filename), display: true) { _, _, _ in }
        return true
    }
}

public class DeckWindowController: NSWindowController {
    
    /// Sets the currently presented deck. Note: setting this resets the presented card.
    public override var document: AnyObject? {
        didSet {
            guard let deck = self.document as? DeckDocument else { return }
            self.presentingCard = deck.cards.first
        }
    }
    
    /// The currently visible card. Note: setting this resets the visible face.
    private var presentingCard: Card? = nil {
        didSet {
            self.faceFront = true
        }
    }
    
    /// The currently visible face of the presented card of the presented deck.
    private var faceFront: Bool = true {
        didSet {
            self.faceViewController?.representedObject = self.faceFront ? self.presentingCard?.front : self.presentingCard?.back
        }
    }
    
    private var faceViewController: FaceViewController? {
        return self.contentViewController as? FaceViewController
    }
    
    private lazy var responseController: ResponseViewController? = {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ResponseController")) as! ResponseViewController
        return vc
    }()
    
    public override func windowDidLoad() {
        self.window?.titleVisibility = .hidden
        self.faceViewController?.pressHandler = {
            if self.faceFront {
                self.flip(nil)
            } else {
                self.contentViewController?.presentViewControllerAsSheet(self.responseController!)
            }
        }
        self.responseController?.responseHandler = { _ in
            self.next(nil)
        }
    }
    
    /// Flip the current card.
    @IBAction public func flip(_ sender: NSButton!) {
        self.faceFront = !self.faceFront
    }
    
    public override func keyDown(with event: NSEvent) {
        // Ignore the silly beep.
    }
    
    // Patch spacebar into the flipping mechanism.
    public override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            self.faceViewController?.pressHandler?()
        }
    }
    
    /// Show the previous card in the deck and wrap around if at the start.
    @IBAction public func prev(_ sender: NSButton!) {
        guard let deck = self.document as? DeckDocument, let card = self.presentingCard else { return }
        let nextIdx = deck.cards.index { $0.frontURL == card.frontURL }?.advanced(by: -1) ?? 0
        self.presentingCard = deck.cards[safe: nextIdx] ?? deck.cards.last
    }
    
    /// Show the next card in the deck and wrap around if at the end.
    @IBAction public func next(_ sender: NSButton!) {
        guard let deck = self.document as? DeckDocument, let card = self.presentingCard else { return }
        let nextIdx = deck.cards.index { $0.frontURL == card.frontURL }?.advanced(by: +1) ?? 0
        self.presentingCard = deck.cards[safe: nextIdx] ?? deck.cards.first
    }
}

/// Presents a face of a card (text or image).
public class FaceViewController: NSViewController {
    @IBOutlet private var imageView: NSImageView! = nil
    @IBOutlet private var textView: NSTextView! = nil
    @IBOutlet private var noneLabel: NSTextField! = nil
    
    // Used by clients to track if pressed.
    public var pressHandler: (() -> ())? = nil
    
    public override func viewDidLoad() {
        self.representedObject = nil
    }
    
    public override func mouseUp(with event: NSEvent) {
        guard self.view.mouse(self.view.convert(event.locationInWindow, from: nil),
                              in: self.view.bounds) else { return }
        self.pressHandler?()
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

public class ResponseViewController: NSViewController {
    
    // Used by clients to track if pressed.
    public var responseHandler: ((Int) -> ())? = nil
    
    public override func keyDown(with event: NSEvent) {
        // Ignore the silly beep.
    }
    
    public override func keyUp(with event: NSEvent) {
        guard event.keyCode >= 18 && event.keyCode <= 23 else { return }
        self.dismiss(self)
        self.responseHandler?(Int(event.keyCode - 17))
    }
    
    @IBAction func respond(_ sender: NSSegmentedControl!) {
        self.dismiss(self)
        self.responseHandler?(sender.tag)
    }
}

/// Display a list of each saved deck and each card within them, available for editing.
public class DeckListController: NSViewController, NSBrowserDelegate {
    
    @IBOutlet var header: NSViewController?
    @IBOutlet var preview: NSViewController?
    
    public func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        /*if item == nil {
            return Deck.all.count
        } else {
            return (item as! Deck).cards.count
        }*/
        return 0
    }
    
    public func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        /*if item == nil {
            return Deck.all[index]
        } else {
            return (item as! Deck).cards[index]
        }*/
        return "nil"
    }
    
    public func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        return (item is Card)
    }
    
    public func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        /*if let item = item as? Deck {
            return item.url.lastPathComponent
        } else if let item = item as? Card {
            return item.frontURL.lastPathComponent.components(separatedBy: ".").first ?? "card"
        }*/
        return "???"
    }
    
    public func browser(_ browser: NSBrowser, previewViewControllerForLeafItem item: Any) -> NSViewController? {
        print("PREVIEW", item)
        return self.preview
    }
    
    /// Add a new card by taking a screenshot and marking it up.
    // TODO: MAKE THIS DO REAL THINGS
    @IBAction public func addCard(_ sender: NSButton!) {
        
        // Hide the window, take the screenshot, and show the window afterwards!
        NSApp.hide(nil)
        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    self.view.window?.sheetParent?.makeKeyAndOrderFront(nil)
                }
            }
            do {
                let image = try NSScreen.screenshot()
                let marked = try image.markup(in: self.view)
                
                // Format the date...
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .medium
                let date = df.string(from: Date())
                
                try image.write(to: URL(fileURLWithPath: "/Users/aditya/Desktop/Card Front \(date).png"), type: .png)
                try marked.write(to: URL(fileURLWithPath: "/Users/aditya/Desktop/Card Back \(date).png"), type: .png)
            } catch(let error) {
                DispatchQueue.main.async {
                    self.presentError(error)
                    NSApp.unhide(nil)
                }
            }
        }
    }
}

