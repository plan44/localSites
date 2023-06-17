//
//  PrefsWindow.swift
//  LocalSites
//
//  Created by Lukas Zeller on 13.10.17.
//  Copyright © 2017 plan44.ch. All rights reserved.
//

import Cocoa

protocol PrefsWindowDelegate {
  func prefsDidUpdate()
}

class PrefsWindow: NSWindowController, NSWindowDelegate {

  @IBOutlet weak var monochromeIconCheckbox: NSButton!

  var delegate: PrefsWindowDelegate?

  override var windowNibName : NSNib.Name! {
    return NSNib.Name("PrefsWindow")
  }

  override func windowDidLoad() {
    super.windowDidLoad()

    self.window?.center()
    self.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    let defaults = UserDefaults.standard
    let monochrome = defaults.bool(forKey: "monochromeIcon")
    monochromeIconCheckbox.state = monochrome ? NSControl.StateValue.on : NSControl.StateValue.off
  }

  func windowWillClose(_ notification: Notification) {
    let defaults = UserDefaults.standard
    defaults.setValue(monochromeIconCheckbox.state==NSControl.StateValue.on, forKey: "monochromeIcon")
    delegate?.prefsDidUpdate()
  }

}
