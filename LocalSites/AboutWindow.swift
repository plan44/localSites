//
//  AboutWindow.swift
//  LocalSites
//
//  Created by Lukas Zeller on 25.09.17.
//  Copyright © 2017 plan44.ch. All rights reserved.
//

import Cocoa

class AboutWindow: NSWindowController {

  @IBOutlet weak var iconImage: NSImageView!

  @IBOutlet weak var versionLabel: NSTextField!
  
  override var windowNibName : NSNib.Name! {
    return NSNib.Name(rawValue: "AboutWindow")
  }

  override func windowDidLoad() {
    super.windowDidLoad()

    iconImage.image = NSImage(named:NSImage.Name(rawValue: "AppIcon"))
    self.window?.center()
    self.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
      versionLabel.stringValue = "v\(version)"
    }

  }

}
