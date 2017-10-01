import Cocoa

/// Presents a reversible card (text or image). Can be used in an NSCollectionView as well.
public class CardViewController: NSCollectionViewItem {
    
    /// Describes the three states the controller can move a card in.
    /// front: the front face of the card is being displayed.
    /// back: the back face of the card is being displayed.
    /// complete: the front face of the card will be re-displayed.
    public enum FlipState {
        case front, back, complete
    }
    
    // Used by clients to track if pressed.
    public var action: ((FlipState) -> ())? = nil
    
    public var placeholderString = "No Card" {
        didSet {
            if self.representedObject == nil {
                DispatchQueue.main.async {
                    self.textField?.stringValue = self.placeholderString
                }
            }
        }
    }
    
    public override func viewDidLoad() {
        self.representedObject = nil
    }
    
    public override func mouseUp(with event: NSEvent) {
        guard self.view.mouse(self.view.convert(event.locationInWindow, from: nil),
                              in: self.view.bounds) else { return }
        self.action?(.complete)
    }
    
    /// Toggle between the image view and text label based on the represented object type.
    public override var representedObject: Any? {
        didSet {
            DispatchQueue.main.async {
                if let rep = self.representedObject as? String {
                    self.imageView?.isHidden = true
                    self.textField?.isHidden = false
                    
                    self.imageView?.image = nil
                    self.textField?.stringValue = rep
                } else if let rep = self.representedObject as? NSAttributedString {
                    self.imageView?.isHidden = true
                    self.textField?.isHidden = true
                    
                    self.imageView?.image = nil
                    self.textField?.attributedStringValue = rep
                } else if let rep = self.representedObject as? NSImage {
                    self.imageView?.isHidden = false
                    self.textField?.isHidden = true
                    
                    self.imageView?.image = rep
                    self.textField?.stringValue = ""
                } else {
                    self.imageView?.isHidden = true
                    self.textField?.isHidden = false
                    
                    self.imageView?.image = nil
                    self.textField?.stringValue = self.placeholderString
                }
                self.view.needsLayout = true
            }
        }
    }
    
    /// Adjust the none string's color to be quieter and font size to fit the view.
    public override func viewDidLayout() {
        self.textField?.textColor = self.representedObject == nil ? .tertiaryLabelColor : .labelColor
        self.textField?.font = NSFont.systemFont(ofSize: self.textField!.stringValue.fittingSize(within: self.view.bounds.insetBy(dx: 16, dy: 16).size))
    }
}
