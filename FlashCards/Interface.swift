import Cocoa

// TODO: Add alarm mode: cover as many cards as you can in X seconds.

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
    
    // Default per-card timer interval.
    public static var defaultTimerInterval: TimeInterval = 10.0
    
    /// Sets the currently presented deck. Note: setting this resets the presented card.
    public override var document: AnyObject? {
        didSet {
            guard let deck = self.document as? Deck else { return }
            DispatchQueue.main.async {
                if deck.cards.count == 0 {
                    // Auto-open edit panel to start adding cards.
                    //self.edit(nil)
                } else {
                    self.presentingCard = deck.cards.random()
                }
            }
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
            self.faceViewController?.representedObject = self.faceFront ? self.presentingCard?.frontValue : self.presentingCard?.backValue
        }
    }
    
    @IBOutlet var timer: NSButton!
    
    private var faceViewController: FaceViewController? {
        return self.contentViewController as? FaceViewController
    }
    
    private lazy var responseController: ResponseViewController? = {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ResponseViewController")) as! ResponseViewController
        return vc
    }()
    
    private lazy var listController: DeckListController? = {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("DeckListController")) as! DeckListController
        return vc
    }()
    
    // Present a new (if possible) shuffled card from the deck.
    private func shuffleCard() {
        guard let deck = self.document as? Deck else { return }
        var card = deck.cards.random()
        while self.presentingCard != nil && self.presentingCard == card && deck.cards.count > 1 {
            card = deck.cards.random() // Avoid same-card collisions
        }
        self.presentingCard = card
    }
    
    public override func windowDidLoad() {
        self.window?.titleVisibility = .hidden
        
        // Randomize the next card.
        self.responseController?.responseHandler = {
            self.presentingCard?.grade(Card.Grade(rawValue: $0)!)
            self.shuffleCard()
            if self.timeLeft != nil || self.hadTimerInterval {
                self.hadTimerInterval = false
            }
        }
        
        // Flip the card or show a response dialog.
        self.faceViewController?.pressHandler = {
            if self.faceFront {
                self.faceFront = !self.faceFront
            } else {
                if self.timeLeft != nil { self.hadTimerInterval = true }
                self.contentViewController?.presentViewControllerAsSheet(self.responseController!)
            }
        }
        
        // Short circuit when timer goes off.
        self.timerAlarmHandler = {
            self.presentingCard?.grade(.null)
            self.shuffleCard()
            self.timeLeft = DeckWindowController.defaultTimerInterval
        }
    }
    
    private var timerAlarmHandler: (() -> ())? = nil
    
    // Handles timesync with the UI button and <= 0 values.
    private var timeLeft: TimeInterval? = nil {
        didSet {
            
            // If the timer reached 0sec, turn it off and handle it.
            if self.timeLeft != nil && self.timeLeft! <= 0.0 {
                self.timeLeft = nil
                self.timerAlarmHandler?()
            } else if self.timeLeft != nil && self.timeLeft! > 0.0 {
                
                // If the timeLeft was set, automatically decrement it each second.
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    guard self.timeLeft != nil else { return }
                    self.timeLeft! -= 1.0
                }
            }
            
            // Update UI title.
            if self.timeLeft == nil {
                self.timer.title = "TIMER OFF"
            } else {
                self.timer.title = "\(Int(self.timeLeft!))"
            }
        }
    }
    
    // Preserve the info of whether we previously had a timer going or not
    // if a card was responded to.
    var hadTimerInterval = false {
        didSet { self.timeLeft = self.hadTimerInterval ? nil : DeckWindowController.defaultTimerInterval }
    }
    @IBAction func timer(_ sender: NSButton!) {
        self.timeLeft = self.timeLeft != nil ? nil : DeckWindowController.defaultTimerInterval
    }
    
    @IBAction func edit(_ sender: NSButton!) {
        guard let deck = self.document as? Deck else { return }
        self.listController?.representedObject = deck
        self.timeLeft = nil // disable the timer
        self.contentViewController?.presentViewControllerAsSheet(self.listController!)
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
}

/// Presents a face of a card (text or image).
public class FaceViewController: NSViewController {
    @IBOutlet private var imageView: NSImageView! = nil
    @IBOutlet private var textView: NSTextView! = nil
    @IBOutlet private var textLabel: NSTextField! = nil
    
    // Used by clients to track if pressed.
    public var pressHandler: (() -> ())? = nil
    
    public var noneString = "No Card"
    
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
                    self.textView.isHidden = true
                    self.textLabel.isHidden = false
                    
                    self.imageView.image = nil
                    self.textView.string = ""
                    self.textLabel.stringValue = rep
                } else if let rep = self.representedObject as? NSAttributedString {
                    self.imageView.isHidden = true
                    self.textView.isHidden = false
                    self.textLabel.isHidden = true
                    
                    self.imageView.image = nil
                    self.textView.textStorage?.setAttributedString(rep)
                    self.textLabel.stringValue = ""
                } else if let rep = self.representedObject as? NSImage {
                    self.imageView.isHidden = false
                    self.textView.isHidden = true
                    self.textLabel.isHidden = true
                    
                    self.imageView.image = rep
                    self.textView.string = ""
                    self.textLabel.stringValue = ""
                } else {
                    self.imageView.isHidden = true
                    self.textView.isHidden = true
                    self.textLabel.isHidden = false
                    
                    self.imageView.image = nil
                    self.textView.string = ""
                    self.textLabel.stringValue = self.noneString
                }
                
                /// Adjust the none string's color to be quieter.
                self.textLabel.textColor = self.representedObject == nil ? .tertiaryLabelColor : .labelColor
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
        self.responseHandler?(Int(event.keyCode - 18))
    }
    
    @IBAction func respond(_ sender: NSSegmentedControl!) {
        self.dismiss(self)
        self.responseHandler?(sender.tag)
    }
}

/// Display a list of each saved deck and each card within them, available for editing.
public class DeckListController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var preview: ReferencingView!
    
    public override func viewWillAppear() {
        self.tableView.enclosingScrollView?.scrollerStyle = .overlay // FIXME in IB
        self.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
        
        self.previewController?.noneString = "No Card Selected"
        self.previewController?.pressHandler = {
            guard self.tableView.selectedRow > 0 else { return }
            let card = self.cards[self.tableView.selectedRow]
            
            // can't flip back!
            self.previewController?.representedObject = card.backValue
        }
    }
    
    private var cards: [Card] {
        return (self.representedObject as? Deck)?.cards ?? []
    }
    
    private var previewController: FaceViewController? {
        return self.childViewControllers.first as? FaceViewController
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return self.cards.count
    }
    
    public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return self.cards[row]
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Default"), owner: self) as? NSTableCellView
        view?.textField?.stringValue = "\(row + 1)" //self.cards[row]
        return view
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        if self.tableView.selectedRowIndexes.count == 1 {
            let card = self.cards[self.tableView.selectedRow]
            self.previewController?.representedObject = card.frontValue
        } else {
            self.previewController?.representedObject = nil
        }
    }
    
    @IBAction func imageClick(_ sender: NSImageView!) {
        guard self.tableView.selectedRowIndexes.count == 1 else { return }
        //deck.cards[self.tableView.selectedRow]
        print("click!", sender)
    }
    
    @IBAction func removeCard(_ sender: NSButton!) {
        guard let deck = self.representedObject as? Deck else { return }
        self.tableView.selectedRowIndexes.reversed().forEach {
            deck.cards.remove(at: $0)
        }
        self.tableView.reloadData()
    }
    
    
    /// Add a new card with text contents.
    @IBAction func addCard(_ sender: NSMenuItem!) {
        guard let deck = self.representedObject as? Deck else { return }
        deck.cards.append(Card(front: "Front", back: "Back"))
        self.tableView.reloadData()
    }
    
    /// Add a new card by taking a screenshot and marking it up.
    @IBAction public func screenshot(_ sender: NSMenuItem!) {
        guard let deck = self.representedObject as? Deck else { return }
        
        // Hide the window, take the screenshot, and show the window afterwards!
        NSApp.hide(nil)
        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    NSApp.unhide(nil)
                    self.view.window?.sheetParent?.makeKeyAndOrderFront(nil)
                }
            }
            do {
                let image = try NSScreen.screenshot()
                let marked = try image.markup(in: self.view)
                
                // Generate the correct unique file locations.
                guard let base = deck.fileURL?.appendingPathComponent("Contents") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let id = UUID().uuidString
                
                let imageURL = URL(fileURLWithPath: "\(id) - Screenshot.png", relativeTo: base)
                let markedURL = URL(fileURLWithPath: "\(id) - Markup.png", relativeTo: base)
                
                try image.write(to: imageURL, type: .png)
                try marked.write(to: markedURL, type: .png)
                
                // Update with a new card.
                DispatchQueue.main.async {
                    deck.cards.append(Card(front: imageURL.absoluteString, back: markedURL.absoluteString))
                    self.tableView.reloadData()
                }
            } catch(let error) {
                DispatchQueue.main.async {
                    self.presentError(error)
                    NSApp.unhide(nil)
                }
            }
        }
    }
}

