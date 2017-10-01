import Cocoa

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
            guard let deck = self.document as? Deck else { return }
            self.cardViewController?.representedObject = self.faceFront ?
                self.presentingCard?.frontValue(deck.fileURL!) :
                self.presentingCard?.backValue(deck.fileURL!)
        }
    }
    
    @IBOutlet var timer: NSButton!
    
    private var cardViewController: CardViewController? {
        return self.contentViewController?.childViewControllers[0] as? CardViewController
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
        self.cardViewController?.action = { _ in
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
            
            // TODO: Prevent long bezels:
            self.timer.sizeToFit()
            let item = self.window?.toolbar?.items.first { $0.label == "Timer" }
            item?.minSize = self.timer.fittingSize
            item?.maxSize = self.timer.fittingSize
        }
    }
    
    // Preserve the info of whether we previously had a timer going or not
    // if a card was responded to.
    var hadTimerInterval = false {
        didSet { self.timeLeft = self.hadTimerInterval ? nil : DeckWindowController.defaultTimerInterval }
    }
    @IBAction func timer(_ sender: Any!) {
        self.timeLeft = self.timeLeft != nil ? nil : DeckWindowController.defaultTimerInterval
    }
    
    @IBAction func edit(_ sender: Any!) {
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
            self.cardViewController?.action?(.complete)
        }
    }
}
