import Cocoa

public enum ScreenshotError: LocalizedError {
    case cancelled
    case cannotMarkup
    case markupCancelled
    
    public var errorDescription: String? {
        switch self {
        case .cancelled: return "The screenshot was cancelled."
        case .cannotMarkup: return "Can't markup the image."
        case .markupCancelled: return "The markup was cancelled."
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .cancelled: return "You may have cancelled the screenshot."
        case .cannotMarkup: return "Couldn't find the markup service."
        case .markupCancelled: return "You cancelled the markup dialog."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .cancelled: return "Try taking the screenshot again. Be sure not to single-click, but drag a region or press space to select a window."
        case .cannotMarkup: return "Try upgrading your Mac to the latest version first."
        case .markupCancelled: return "Try marking up the image again. Be sure not to press cancel."
        }
    }
}

extension NSScreen {
    
    /// Take a screenshot using the system function and provide it as an image.
    public static func screenshot() throws -> NSImage {
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
        
        guard img != nil else { throw ScreenshotError.cancelled }
        return img!
    }
}


extension NSImage {
    
    /// Trigger the Preview MarkupUI for the given image.
    public func markup(in view: NSView) throws -> NSImage {
        class MarkupDelegate: NSObject, NSSharingServiceDelegate {
            private let view: NSView
            private let handler: (NSImage?) -> ()
            init(view: NSView, handler: @escaping (NSImage?) -> ()) {
                self.view = view
                self.handler = handler
            }
            
            func sharingService(_ sharingService: NSSharingService, sourceFrameOnScreenForShareItem item: Any) -> NSRect {
                return self.view.window!.frame.insetBy(dx: 0, dy: 16).offsetBy(dx: 0, dy: -16)
            }
            
            func sharingService(_ sharingService: NSSharingService, sourceWindowForShareItems items: [Any], sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
                return self.view.window!
            }
            
            func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
                let itp = items[0] as! NSItemProvider
                itp.loadItem(forTypeIdentifier: "public.url", options: nil) { (url, _) in
                    self.handler(NSImage(contentsOf: url as! URL))
                }
            }
            
            func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
                self.handler(nil)
            }
        }
        
        var img: NSImage? = nil
        let s = DispatchSemaphore(value: 0)
        
        // Allocate the MarkupUI service.
        var service_ = NSSharingService(named: NSSharingService.Name(rawValue: "com.apple.MarkupUI.Markup"))
        if service_ == nil {
            service_ = NSSharingService(named: NSSharingService.Name(rawValue: "com.apple.Preview.Markup"))
        }
        guard let service = service_ else { throw ScreenshotError.cannotMarkup }
        
        // Perform the UI action.
        let markup = MarkupDelegate(view: view) {
            img = $0; s.signal()
        }
        service.delegate = markup
        service.perform(withItems: [self])
        
        s.wait()
        guard img != nil else { throw ScreenshotError.markupCancelled }
        return img!
    }
    
    /// Save an arbitrary image format to the given file type.
    func write(to url: URL, type: NSBitmapImageRep.FileType) throws {
        guard
            let imageData = tiffRepresentation,
            let imageRep = NSBitmapImageRep(data: imageData),
            let fileData = imageRep.representation(using: type, properties: [.compressionFactor: 1.0]) else {
                throw CocoaError(.fileNoSuchFile)
        }
        try fileData.write(to: url)
    }
}

extension NSMenu {
    
    /// Convenience to open a menu from an IB sender.
    @IBAction public func open(_ sender: NSControl) {
        self.popUp(positioning: self.items.first, at: NSPoint.zero, in: sender)
    }
}

public extension Collection where Index == Int {
    public func random() -> Iterator.Element? {
        guard !self.isEmpty else { return nil }
        return self[Int(arc4random_uniform(UInt32(self.endIndex)))]
    }
}

extension Array {
    
    public subscript(safe index: Int) -> Element? {
        return index >= 0 && index < self.count ? self[index] : nil
    }
}

public class FirstResponderView: NSView {
    public override var acceptsFirstResponder: Bool {
        return true
    }
}

// Clickable NSImageView
public class ClickableImageView: NSImageView {
    
    public override func mouseDown(with event: NSEvent) {
        if event.type != .leftMouseDown {
            super.mouseDown(with: event)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        if event.type != .leftMouseUp {
            super.mouseUp(with: event)
        } else {
            let point = self.convert(event.locationInWindow, from: nil)
            if self.mouse(point, in: self.bounds) && self.action != nil {
                NSApp.sendAction(self.action!, to: self.target, from: self)
            }
        }
    }
}

public extension String {
    
    /// Returns the largest font size capable of fitting within the bounds given.
    /// maximumFactor: the percentage of the bounds' smallest dimension to use as the
    /// maximum size. absoluteMinimum: the absolute smallest font size possible.
    public func fittingSize(within bounds: CGSize, maximumFactor: CGFloat = 0.25,
                            absoluteMinimum minSize: CGFloat = 12.0) -> CGFloat
    {
        // Helper function (boundingRect) to get the bounding size from a string with a font size.
        func bounding1(_ str: String, _ currSize: CGFloat) -> NSSize? {
            let fit = NSSize(width: bounds.width, height: .greatestFiniteMagnitude)
            let res = (str as NSString).boundingRect(with: fit,
                             options: [.usesLineFragmentOrigin, .usesFontLeading],
                             attributes: [.font: NSFont.systemFont(ofSize: currSize),
                                          .paragraphStyle: NSParagraphStyle.default])
            return Optional(NSSize(width: ceil(res.width), height: ceil(res.height)))
        }
        
        // An alternative CTFramesetter-based version.
        func bounding2(_ str: String, _ currSize: CGFloat) -> NSSize? {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = NSFont.systemFont(ofSize: 12.0).leading
            let attr = NSAttributedString(string: str, attributes: [
                .font: NSFont.systemFont(ofSize: currSize),
                .paragraphStyle: paragraphStyle
            ])
            let set = CTFramesetterCreateWithAttributedString(attr)
            let fit = NSSize(width: bounds.width, height: .greatestFiniteMagnitude)
            let res = CTFramesetterSuggestFrameSizeWithConstraints(set, CFRangeMake(0, 0), nil, fit, nil)
            return Optional(NSSize(width: ceil(res.width), height: ceil(res.height)))
        }
        
        // Loop down until the largest font size fitting the bounds.
        var currSize = ceil(min(bounds.width, bounds.height) * maximumFactor)
        while let sz = bounding2(self, currSize), (sz.height > bounds.height || sz.width > bounds.width) && currSize > minSize {
            currSize -= 1.0
        }
        return currSize <= minSize ? minSize : currSize
    }
}
