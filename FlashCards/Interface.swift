import Cocoa
import Quartz.ImageKit

// TODO: Add alarm mode: cover as many cards as you can in X seconds.

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false//true
    }
    
    /// Add an opened deck to the saved deck list.
    public func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        NSDocumentController.shared.openDocument(withContentsOf: URL(fileURLWithPath: filename), display: true) { _, _, _ in }
        return true
    }
}

public class ResponseViewController: NSViewController {
    
    @IBOutlet var incorrectResponses: NSSegmentedControl!
    @IBOutlet var correctResponses: NSSegmentedControl!
    
    // Used by clients to track if pressed.
    public var responseHandler: ((Int) -> ())? = nil
    
    public override func keyDown(with event: NSEvent) {
        // Ignore the silly beep.
        guard event.keyCode >= 18 && event.keyCode <= 23 else { return }
        self.incorrectResponses.selectSegment(withTag: Int(event.keyCode - 18))
        self.correctResponses.selectSegment(withTag: Int(event.keyCode - 18))
    }
    
    public override func keyUp(with event: NSEvent) {
        guard event.keyCode >= 18 && event.keyCode <= 23 else { return }
        _ = self.incorrectResponses.cell?.perform(Selector(("_deselectAllSegments")))
        _ = self.correctResponses.cell?.perform(Selector(("_deselectAllSegments")))
        
        self.dismiss(self)
        self.responseHandler?(Int(event.keyCode - 18))
    }
    
    @IBAction func respond(_ sender: NSSegmentedControl!) {
        self.dismiss(self)
        self.responseHandler?(sender.tag)
    }
}

public class EditTextController: NSViewController {
    @IBOutlet var frontTextView: NSTextView!
    @IBOutlet var backTextView: NSTextView!
    @IBOutlet var frontImageView: DragDropImageView!
    @IBOutlet var backImageView: DragDropImageView!
    
    public override func viewDidLoad() {
        self.frontImageView.target = self.frontImageView
        self.frontImageView.doubleAction = #selector(DragDropImageView.openPanel(_:))
        self.backImageView.target = self.backImageView
        self.backImageView.doubleAction = #selector(DragDropImageView.openPanel(_:))
    }
}

public class EditImageController: NSViewController {
    @IBOutlet var frontImageView: NSImageView!
    @IBOutlet var backImageView: NSImageView!
}
