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
            guard let deck = self.document as? Deck else { return }
            self.presentingCard = deck.cards.random()
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
    
    public override func windowDidLoad() {
        self.window?.titleVisibility = .hidden
        
        // Randomize the next card.
        self.responseController?.responseHandler = { _ in
            guard let deck = self.document as? Deck else { return }
            var card = deck.cards.random()
            while self.presentingCard != nil && self.presentingCard == card {
                card = deck.cards.random()
            }
            self.presentingCard = card
        }
        
        self.faceViewController?.pressHandler = {
            if self.faceFront {
                self.faceFront = !self.faceFront
            } else {
                self.contentViewController?.presentViewControllerAsSheet(self.responseController!)
            }
        }
        
        // Short circuit when timer goes off.
        self.timerAlarmHandler = {
            self.faceFront = false
            self.contentViewController?.presentViewControllerAsSheet(self.responseController!)
        }
    }
    
    private var timerAlarmHandler: (() -> ())? = nil
    
    // Handles timesync with the UI button and <= 0 values.
    private var timeLeft: TimeInterval? = nil {
        didSet {
            if self.timeLeft != nil && self.timeLeft! <= 0.0 {
                self.timeLeft = nil
                self.timerAlarmHandler?()
            }
            if self.timeLeft == nil {
                self.timer.title = "TIMER OFF"
            } else {
                self.timer.title = "\(Int(self.timeLeft!))"
            }
        }
    }
    
    // Handles recursing each second.
    private func updateTimer() {
        guard self.timeLeft != nil else { return }
        self.timeLeft! -= 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: self.updateTimer)
    }
    
    @IBAction func timer(_ sender: NSButton!) {
        if self.timeLeft == nil {
            self.timeLeft = 60.0
            self.updateTimer()
        } else {
            self.timeLeft = nil
        }
    }
    
    @IBAction func edit(_ sender: NSButton!) {
        guard let deck = self.document as? Deck else { return }
        self.listController?.representedObject = deck
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
public class DeckListController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var frontImage: NSImageView!
    @IBOutlet var backImage: NSImageView!
    @IBOutlet var noneLabel: NSTextField!
    
    public override func viewWillAppear() {
        self.tableView.enclosingScrollView?.scrollerStyle = .overlay // FIXME in IB
        self.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
    }
    
    private var cards: [Card] {
        return (self.representedObject as? Deck)?.cards ?? []
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
            
            self.frontImage.image = card.front as? NSImage
            self.backImage.image = card.back as? NSImage
            self.frontImage.isHidden = false
            self.backImage.isHidden = false
            self.noneLabel.isHidden = true
        } else {
            self.frontImage.image = nil
            self.backImage.image = nil
            self.frontImage.isHidden = true
            self.backImage.isHidden = true
            self.noneLabel.isHidden = false
        }
    }
    
    @IBAction func imageClick(_ sender: NSImageView!) {
        print("click!", sender)
    }
    
    @IBAction func addCard(_ sender: NSButton!) {
        print("Add card!")
    }
    
    @IBAction func removeCard(_ sender: NSButton!) {
        print("Remove cards!", self.tableView.selectedRowIndexes)
    }
    
    /// Add a new card by taking a screenshot and marking it up.
    // TODO: MAKE THIS DO REAL THINGS
    @IBAction public func screenshot(_ sender: NSButton!) {
        
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

