import Cocoa

/// Presents a reversible card (text or image).
public class CardViewController: NSViewController {
    
    /// Describes the three states the controller can move a card in.
    /// front: the front face of the card is being displayed.
    /// back: the back face of the card is being displayed.
    /// complete: the front face of the card will be re-displayed.
    public enum FlipState {
        case front, back, complete
    }
    
    @IBOutlet private var imageView: NSImageView! = nil
    @IBOutlet private var textLabel: NSTextField! = nil
    
    // Used by clients to track if pressed.
    public var action: (() -> ())? = nil
    
    public var placeholderString = "No Card" {
        didSet {
            if self.representedObject == nil {
                self.textLabel.stringValue = self.placeholderString
            }
        }
    }
    
    public override func viewDidLoad() {
        self.representedObject = nil
    }
    
    public override func mouseUp(with event: NSEvent) {
        guard self.view.mouse(self.view.convert(event.locationInWindow, from: nil),
                              in: self.view.bounds) else { return }
        self.action?()
    }
    
    /// Toggle between the image view and text label based on the represented object type.
    public override var representedObject: Any? {
        didSet {
            DispatchQueue.main.async {
                if let rep = self.representedObject as? String {
                    self.imageView.isHidden = true
                    self.textLabel.isHidden = false
                    
                    self.imageView.image = nil
                    self.textLabel.stringValue = rep
                } else if let rep = self.representedObject as? NSAttributedString {
                    self.imageView.isHidden = true
                    self.textLabel.isHidden = true
                    
                    self.imageView.image = nil
                    self.textLabel.attributedStringValue = rep
                } else if let rep = self.representedObject as? NSImage {
                    self.imageView.isHidden = false
                    self.textLabel.isHidden = true
                    
                    self.imageView.image = rep
                    self.textLabel.stringValue = ""
                } else {
                    self.imageView.isHidden = true
                    self.textLabel.isHidden = false
                    
                    self.imageView.image = nil
                    self.textLabel.stringValue = self.placeholderString
                }
                self.view.needsLayout = true
            }
        }
    }
    
    /// Adjust the none string's color to be quieter and font size to fit the view.
    public override func viewDidLayout() {
        self.textLabel.textColor = self.representedObject == nil ? .tertiaryLabelColor : .labelColor
        self.textLabel.font = NSFont.systemFont(ofSize: self.textLabel.stringValue.fittingSize(within: self.view.bounds.insetBy(dx: 16, dy: 16).size))
    }
}
