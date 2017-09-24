//
//  SitesMenuController.swift
//  LocalSites
//
//  Created by Lukas Zeller on 24.09.17.
//  Copyright © 2017 plan44.ch. All rights reserved.
//

import Cocoa
import Foundation

class SitesMenuController: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {

  @IBOutlet weak var statusMenu: NSMenu!

  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength);

  let netServiceBrowser = NetServiceBrowser();

  var services: Set<NetService> = Set();

  var numStaticMenuItems = 0;

  var pendingResolves = 0;

  override func awakeFromNib() {
    // Initialize the application
    let icon = NSImage(named: NSImage.Name(rawValue: "statusIcon"))
    //icon?.isTemplate = true // just use shape, automatically black in normal and white in dark mode
    statusItem.image = icon
    statusItem.menu = statusMenu
    numStaticMenuItems = statusMenu.items.count

    // start network service search
    netServiceBrowser.delegate = self
    netServiceBrowser.searchForServices(ofType: "_http._tcp", inDomain: "local")
  }

  // MARK: ==== NetServiceBrowser delegate

  func netServiceBrowser(_: NetServiceBrowser , didFind service: NetService, moreComing: Bool) {
    print("didFind '\(service.name)', domain:\(service.domain), hostname:\(service.hostName ?? "<none>") - \(moreComing ? "more coming" : "all done")")
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
    print("didRemove '\(service.name)' domain:\(service.domain), hostname:\(service.hostName ?? "<none>") - \(moreComing ? "more coming" : "all done")")
    services.remove(service)
    if !moreComing {
      refreshMenu()
    }
  }


  func netServiceBrowserWillSearch(_:NetServiceBrowser) {
    // Tells the delegate that a search is commencing.
    print("netServiceBrowserWillSearch")
  }

  func netServiceBrowser(_:NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
    // Tells the delegate that a search was not successful.
    print("netServiceBrowser didNotSearch:\(errorDict)")
  }

  func netServiceBrowserDidStopSearch(_:NetServiceBrowser) {
    // Tells the delegate that a search was stopped.
    print("netServiceBrowserDidStopSearch")
  }

  // MARK: ==== NetServiceBrowser delegate

  func netServiceDidResolveAddress(_ service: NetService) {
    print("netService '\(service.name)' DidResolveAddress hostname:\(service.hostName ?? "<none>")")
    pendingResolves -= 1
    if pendingResolves <= 0 {
      refreshMenu()
      pendingResolves = 0
    }
  }


  func netService(_ service: NetService, didNotResolve errorDict: [String : NSNumber])
  {
    print("netService '\(service.name)' didNotResolve error:\(errorDict)")
    services.remove(service)
    if pendingResolves <= 0 {
      refreshMenu()
      pendingResolves = 0
    }
  }


  // MARK: ==== Updating Menu

  func refreshMenu() {
    for service in services {
      print("- '\(service.name)'    -    '\(service.hostName ?? "<none>")'")
    }
    // sort the services
    let sortedServices : [NetService] = services.sorted(by: { $0.name < $1.name });
    // remove the previous menu items
    for _ in 0..<statusMenu.items.count-numStaticMenuItems {
      statusMenu.removeItem(at: 0)
    }
    for service in sortedServices {
      let item = NSMenuItem();
      item.title = service.name;
      item.representedObject = service;
      item.target = self
      item.action = #selector(localSiteMenuItemSelected)
      item.isEnabled = service.hostName != nil
      statusMenu.insertItem(item, at: 0)
    }
  }


  // MARK: ==== Handling menu actions

  @objc func localSiteMenuItemSelected(_ sender:Any) {
    if let item = sender as? NSMenuItem, let service = item.representedObject as? NetService {
      print("- '\(service.name)'    -    '\(service.hostName ?? "<none>")'")
      if let urlstring = service.hostName {
        if let url = URL(string: "http://" + urlstring) {
          NSWorkspace.shared.open(url)
        }
      }
    }
  }


  // MARK: ==== UI handlers

  @IBAction func quitChosen(_ sender: Any) {
    NSApplication.shared.terminate(self)
  }

}
