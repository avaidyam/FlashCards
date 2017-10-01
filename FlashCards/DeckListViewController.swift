import Cocoa

/// Display a list of each saved deck and each card within them, available for editing.
public class DeckListController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet var tableView: NSTableView!
    
    public override func viewWillAppear() {
        self.tableView.enclosingScrollView?.scrollerStyle = .overlay // FIXME in IB
        self.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
        
        self.previewController?.placeholderString = "No Card Selected"
        self.previewController?.action = { _ in
            guard let deck = self.representedObject as? Deck else { return }
            guard self.tableView.selectedRow >= 0 else { return }
            let card = self.cards[self.tableView.selectedRow]
            
            // can't flip back!
            self.previewController?.representedObject = card.backValue(deck.fileURL!)
        }
    }
    
    private var cards: [Card] {
        return (self.representedObject as? Deck)?.cards ?? []
    }
    
    private var previewController: CardViewController? {
        return self.childViewControllers.first as? CardViewController
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
        guard let deck = self.representedObject as? Deck else { return }
        if self.tableView.selectedRowIndexes.count == 1 {
            let card = self.cards[self.tableView.selectedRow]
            self.previewController?.representedObject = card.frontValue(deck.fileURL!)
        } else {
            self.previewController?.representedObject = nil
        }
    }
    
    /// Display the edit panel for the card's type.
    @IBAction func editCard(_ sender: NSButton!) {
        guard self.tableView.selectedRowIndexes.count == 1 else { return }
        print("edit!", sender)
    }
    
    @IBAction func removeCard(_ sender: NSButton!) {
        guard let deck = self.representedObject as? Deck else { return }
        self.tableView.selectedRowIndexes.reversed().forEach {
            
            // Delete the front card resource reference if it's present.
            let fr = deck.cards[$0].front
            if fr.hasPrefix("ref://") {
                let url = deck.fileURL!.appendingPathComponent("Contents").appendingPathComponent(fr.replacingOccurrences(of: "ref://", with: ""))
                try? FileManager.default.removeItem(at: url)
            }
            
            // Delete the back card resource reference if it's present.
            let bk = deck.cards[$0].back
            if bk.hasPrefix("ref://") {
                let url = deck.fileURL!.appendingPathComponent("Contents").appendingPathComponent(bk.replacingOccurrences(of: "ref://", with: ""))
                try? FileManager.default.removeItem(at: url)
            }
            
            deck.cards.remove(at: $0)
        }
        self.tableView.reloadData()
        self.previewController?.representedObject = nil
    }
    
    public override func dismissViewController(_ viewController: NSViewController) {
        guard let deck = self.representedObject as? Deck else {
            super.dismissViewController(viewController); return
        }
        
        if let vc = viewController as? EditTextController {
            guard vc.frontTextField.stringValue != "" && vc.backTextField.stringValue != "" else {
                self.presentError(CocoaError(.userCancelled)); return
            }
            deck.cards.append(Card(front: vc.frontTextField.stringValue, back: vc.backTextField.stringValue))
            
        } else if let vc = viewController as? EditImageController {
            guard vc.frontImageView.image != nil && vc.backImageView.image != nil else {
                self.presentError(CocoaError(.userCancelled)); return
            }
            
            // Generate the correct unique file locations.
            guard let base = deck.fileURL?.appendingPathComponent("Contents") else { return }
            let frontURL = URL(fileURLWithPath: "\(UUID().uuidString).png", relativeTo: base)
            let backURL = URL(fileURLWithPath: "\(UUID().uuidString).png", relativeTo: base)
            
            do {
                try vc.frontImageView.image?.write(to: frontURL, type: .png)
                try vc.backImageView.image?.write(to: backURL, type: .png)
            } catch(let error) {
                self.presentError(error)
            }
            
            deck.cards.append(Card(front: "ref://" + frontURL.lastPathComponent, back: "ref://" + backURL.lastPathComponent))
        }
        self.tableView.reloadData()
        super.dismissViewController(viewController)
    }
    
    /// Add a new card with text contents.
    @IBAction func addCard(_ sender: Any!) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("EditTextController")) as! EditTextController
        self.presentViewControllerAsSheet(vc)
    }
    
    /// Add a new card with text contents.
    @IBAction func addImageCard(_ sender: Any!) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("EditImageController")) as! EditImageController
        self.presentViewControllerAsSheet(vc)
    }
    
    /// Add a new card by taking a screenshot and marking it up.
    @IBAction public func screenshot(_ sender: Any!) {
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
                    deck.cards.append(Card(front: "ref://" + imageURL.lastPathComponent, back: "ref://" + markedURL.lastPathComponent))
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













/// Display a list of each saved deck and each card within them, available for editing.
public class DeckListController2: NSViewController, NSCollectionViewDelegateFlowLayout, NSCollectionViewDataSource {
    
    @IBOutlet var collectionView: NSCollectionView!
    
    private var cards: [Card] {
        return (self.representedObject as? Deck)?.cards ?? []
    }
    
    public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.cards.count
    }
    
    public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        var v = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CardViewController"), for: indexPath) as? CardViewController
        if v == nil {
            let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
            v = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("CardViewController")) as? CardViewController
            v?.identifier = NSUserInterfaceItemIdentifier(rawValue: "CardViewController")
        }
        
        let deck = self.representedObject as! Deck
        v!.representedObject = self.cards[indexPath.item].frontValue(deck.fileURL!)
        self.configure(item: v!)
        return v!
    }
    
    private func configure(item v: NSCollectionViewItem) {
        let parent = v.view
        let child = v.view.subviews[0]
        
        parent.wantsLayer = true
        parent.layer!.shadowColor = .black
        parent.layer!.shadowOffset = CGSize(width: 0.0, height: -2.0)
        parent.layer!.shadowRadius = 2.0
        parent.layer!.shadowOpacity = 0.5
        
        child.wantsLayer = true
        child.layer!.backgroundColor = NSColor.windowBackgroundColor.cgColor
        child.layer!.cornerRadius = 3.5
        child.layer!.masksToBounds = true
    }
}

