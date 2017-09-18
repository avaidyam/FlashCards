import Cocoa

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
        
        guard img != nil else { throw CocoaError(.fileNoSuchFile) }
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
        }
        
        var img: NSImage? = nil
        let s = DispatchSemaphore(value: 0)
        
        // Allocate the MarkupUI service.
        var service_ = NSSharingService(named: NSSharingService.Name(rawValue: "com.apple.MarkupUI.Markup"))
        if service_ == nil {
            service_ = NSSharingService(named: NSSharingService.Name(rawValue: "com.apple.Preview.Markup"))
        }
        guard let service = service_ else { throw CocoaError(.fileNoSuchFile) }
        
        // Perform the UI action.
        let markup = MarkupDelegate(view: view) {
            img = $0; s.signal()
        }
        service.delegate = markup
        service.perform(withItems: [self])
        
        s.wait()
        guard img != nil else { throw CocoaError(.fileNoSuchFile) }
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

extension Array {
    
    public subscript(safe index: Int) -> Element? {
        return index >= 0 && index < self.count ? self[index] : nil
    }
}
