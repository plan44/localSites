//
//  SitesMenuController.swift
//  LocalSites
//
//  Created by Lukas Zeller on 24.09.17.
//  Copyright © 2017 plan44.ch. All rights reserved.
//

import Cocoa
import Foundation

class SitesMenuController: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, NSMenuDelegate, PrefsWindowDelegate {

  @IBOutlet weak var statusMenu: NSMenu!
  @IBOutlet weak var operationModeItem: NSMenuItem!

  let debugOutput = false

  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength);

  var aboutWindow: AboutWindow!
  var prefsWindow: PrefsWindow!


  var netServiceBrowsers: [NetServiceBrowser] = []

  let domainToBrowse = ""
  let servicesToBrowse = ["_http._tcp.", "_https._tcp.", "_http-alt._tcp."]

  var services: Set<NetService> = Set();

  var numStaticMenuItems = 0;
  let headerMenuItems = 1;
  var menuIsOpen = false;

  var pendingResolves = 0;

  var debugPublish: NetService?;

  enum Browsers {
    case system
    case firefox
    case chrome
    case safari
    case opera
    case icab
  }

  var browser = Browsers.system;

  let browserTexts = [
    Browsers.system : "default browser",
    Browsers.firefox : "Firefox",
    Browsers.chrome : "Chrome",
    Browsers.safari : "Safari",
    Browsers.opera : "Opera",
    Browsers.icab : "iCab"
  ]

  let browserBundleIds = [
    Browsers.firefox : "org.mozilla.firefox",
    Browsers.chrome : "com.google.Chrome",
    Browsers.safari : "com.apple.Safari",
    Browsers.opera : "com.operasoftware.Opera",
    Browsers.icab : "de.icab.iCab"
  ]



  override func awakeFromNib() {
    // Initialize the application
    // - status bar item
    updateIcon()
    statusItem.menu = statusMenu
    numStaticMenuItems = statusMenu.items.count
    refreshMenu() // make sure we display the "no bonjour found" item until bonjour finds something for the first time
    // - about window
    aboutWindow = AboutWindow()
    // - prefs window
    prefsWindow = PrefsWindow()
    prefsWindow.delegate = self
    // - start network service search
    servicesToBrowse.forEach {
      let netServiceBrowser = NetServiceBrowser()
      netServiceBrowser.delegate = self
      netServiceBrowser.searchForServices(ofType: $0, inDomain: domainToBrowse)
      netServiceBrowsers.append(netServiceBrowser) // retain!
    }
  }

  func updateOpStatus() {
    if let om = operationModeItem {
      om.title = "Open in \(browserTexts[browser] ?? "unknown"):"
    }
  }


  // MARK: ==== NSMenuDelegate

  func menuWillOpen(_ menu: NSMenu) {
    if let currentFlags = NSApp.currentEvent?.modifierFlags {
      // - modifier watch
      switch currentFlags.intersection(.deviceIndependentFlagsMask) {
        case [.option] :
          self.browser = Browsers.firefox
        case [.option, .shift] :
          self.browser = Browsers.icab
        case [.control]:
          self.browser = Browsers.chrome
        case [.control, .shift]:
          self.browser = Browsers.opera
        case [.control, .option]:
          self.browser = Browsers.safari
        default:
          self.browser = Browsers.system
      }
    }
    updateOpStatus();
    menuIsOpen = true;
  }

  func menuDidClose(_ menu: NSMenu) {
    menuIsOpen = false;
  }


  // MARK: ==== NetServiceBrowser delegate

  func netServiceBrowser(_: NetServiceBrowser , didFind service: NetService, moreComing: Bool) {
    if debugOutput { print("didFind '\(service.name)', domain:\(service.domain), type:\(service.type), hostname:\(service.hostName ?? "<none>") - \(moreComing ? "more coming" : "all done")") }
    services.insert(service)
    service.delegate = self
    service.resolve(withTimeout:2)
    pendingResolves += 1
    if !moreComing {
      refreshMenu()
    }
  }

  func netServiceBrowser(_:NetServiceBrowser, didRemove service: NetService, moreComing: Bool)
  {
    if debugOutput { print("didRemove '\(service.name)' domain:\(service.domain), hostname:\(service.hostName ?? "<none>") - \(moreComing ? "more coming" : "all done")") }
    services.remove(service)
    if !moreComing {
      refreshMenu()
    }
  }


  func netServiceBrowserWillSearch(_:NetServiceBrowser) {
    // Tells the delegate that a search is commencing.
    if debugOutput { print("netServiceBrowserWillSearch") }
  }

  func netServiceBrowser(_:NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
    // Tells the delegate that a search was not successful.
    print("netServiceBrowser didNotSearch:\(errorDict)")
  }

  func netServiceBrowserDidStopSearch(_:NetServiceBrowser) {
    // Tells the delegate that a search was stopped.
    if debugOutput { print("netServiceBrowserDidStopSearch") }
  }

  // MARK: ==== NetServiceBrowser delegate

  func netServiceDidResolveAddress(_ service: NetService) {
    if debugOutput { print("netService '\(service.name)' DidResolveAddress hostname:\(service.hostName ?? "<none>")") }
    pendingResolves -= 1
    if pendingResolves <= 0 {
      refreshMenu()
      pendingResolves = 0
    }
  }


  func netService(_ service: NetService, didNotResolve errorDict: [String : NSNumber])
  {
    if debugOutput { print("netService '\(service.name)' didNotResolve error:\(errorDict)") }
    services.remove(service)
    if pendingResolves <= 0 {
      refreshMenu()
      pendingResolves = 0
    }
  }


  // MARK: ==== Updating Menu

  func refreshMenu() {
    if false && debugOutput {
      for service in services {
        print("- '\(service.name)'    -    '\(service.hostName ?? "<none>")'")
      }
    }
    // remove the previous menu items
    for _ in 0..<statusMenu.items.count-numStaticMenuItems {
      statusMenu.removeItem(at: headerMenuItems)
    }
    // show new services
    if (services.count>0) {
      // sort the services
      let sortedServices : [NetService] = services.sorted(by: { $0.name.caseInsensitiveCompare($1.name) == .orderedDescending });
      // If there are services discovered in more than one browsing domain, group items by domain
      let byDomain = servicesByDomain(services)
      if byDomain.keys.count > 1 {
        //var separators = [NSMenuItem]()
        byDomain.keys.sorted(by: >).forEach { domain in
          statusMenu.insertItem(NSMenuItem.separator(), at: headerMenuItems)
          let domainItem = NSMenuItem(title: domain, action: nil, keyEquivalent: "")
          domainItem.isEnabled = false
          statusMenu.insertItem(domainItem, at: headerMenuItems)
        }
      }

      for service in sortedServices {
        let item = NSMenuItem();
        let typeComponents = service.type.components(separatedBy: ".")
        let scheme = typeComponents.first?.replacingOccurrences(of: "_", with: "") ?? "http"
        item.title = "\(service.name) \(scheme=="https" ? "🔒" : (scheme=="http" ? "" : "(⚠️\(scheme))"))";
        item.representedObject = service;
        item.target = self
        item.action = #selector(localSiteMenuItemSelected)
        item.isEnabled = service.hostName != nil
        let index = statusMenu.indexOfItem(withTitle: service.domain)
        if index != -1 {
          statusMenu.insertItem(item, at: index+1)
        } else {
          statusMenu.insertItem(item, at: headerMenuItems)
        }
      }
    }
    else {
      // no bonjour items
      let item = NSMenuItem();
      item.title = "No Bonjour websites found";
      item.isEnabled = false
      statusMenu.insertItem(item, at: headerMenuItems)
    }
  }

  private func servicesByDomain(_ services: Set<NetService>) -> [String:[NetService]] {
    services.reduce(into: [String:[NetService]]() ) { dict, service in
      if dict[service.domain] == nil {
        dict[service.domain] = [NetService]()
      }
      dict[service.domain]?.append(service)
    }
  }

  // MARK: ==== Handling menu actions

  @objc func localSiteMenuItemSelected(_ sender:Any) {
    if let item = sender as? NSMenuItem, let service = item.representedObject as? NetService {
      if debugOutput { print("- '\(service.name)'    -    '\(service.hostName ?? "<none>")'") }
      if let hoststring = service.hostName {
        // check for path
        var path = ""
        if let txtData = service.txtRecordData() {
          let txtRecords = NetService.dictionary(fromTXTRecord: txtData)
          if let pathData = txtRecords["path"], let pathStr = String(data:pathData, encoding: .utf8) {
            path = pathStr
            if (path.first ?? "/") != "/" {
              path.insert("/", at: path.startIndex)
            }
          }
        }
        // check for dot at end of hostName
        var hostname = hoststring
        if (hostname.last ?? "_") == "." {
          hostname.remove(at: hostname.index(before: hostname.endIndex))
        }
        let typeComponents = service.type.components(separatedBy: ".")
        let appprotocol = typeComponents.first?.replacingOccurrences(of: "_", with: "") ?? "http"
        let scheme = appprotocol=="http-alt" ? "http" : appprotocol;
        let urlString = "\(scheme)://\(hostname):\(service.port)\(path)"
        if let url = URL(string: urlString) {
          if let browserBundleId = browserBundleIds[browser] {
            if debugOutput { print("have browser '\(browserBundleId)' open '\(url)'") }
            NSWorkspace.shared.open([url], withAppBundleIdentifier: browserBundleId, options: NSWorkspace.LaunchOptions.default, additionalEventParamDescriptor: nil, launchIdentifiers: nil);
          }
          else {
            // use system default browser
            if debugOutput { print("have default browser open '\(url)'") }
            NSWorkspace.shared.open(url)
          }
        }
      }
    }
  }

  // MARK: ==== prefs changes


  func prefsDidUpdate() {
    updateIcon()
  }

  func updateIcon() {
    let defaults = UserDefaults.standard
    let monochrome = defaults.bool(forKey: "monochromeIcon")
    let icon = NSImage(named: NSImage.Name("statusIcon"))
    icon?.isTemplate = monochrome
    statusItem.image = icon
  }


  // MARK: ==== UI handlers

  @IBAction func quitChosen(_ sender: NSMenuItem) {
    NSApplication.shared.terminate(self)
  }

  @IBAction func aboutChosen(_ sender: NSMenuItem) {
    aboutWindow.showWindow(nil)
  }

  @IBAction func prefsChosen(_ sender: NSMenuItem) {
    prefsWindow.showWindow(nil)
  }

}
