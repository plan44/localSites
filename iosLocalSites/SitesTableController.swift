//
//  ViewController.swift
//  iosLocalSites
//
//  Created by Lukas Zeller on 19.08.18.
//  Copyright © 2018 plan44.ch. All rights reserved.
//

import UIKit

class SitesTableController: UITableViewController, NetServiceBrowserDelegate, NetServiceDelegate {

  let debugOutput = true

  let netServiceBrowser = NetServiceBrowser();

  var services: Set<NetService> = Set();
  var sortedServices: [NetService] = Array();

  var pendingResolves = 0;

  // cell reuse id (cells that scroll out of view can be reused)
  let cellReuseIdentifier = "localSiteCell"

  override func viewDidLoad() {
    super.viewDidLoad()
//    // - register table cell
//    self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
    // - start network service search
    netServiceBrowser.delegate = self
    netServiceBrowser.searchForServices(ofType: "_http._tcp", inDomain: "local")
  }


  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


  // MARK: ==== NetServiceBrowser delegate

  func netServiceBrowser(_: NetServiceBrowser , didFind service: NetService, moreComing: Bool) {
    if debugOutput { print("didFind '\(service.name)', domain:\(service.domain), hostname:\(service.hostName ?? "<none>") - \(moreComing ? "more coming" : "all done")") }
    services.insert(service)
    service.delegate = self
    service.resolve(withTimeout:2)
    pendingResolves += 1
    if !moreComing {
      refreshTable()
    }
  }

  func netServiceBrowser(_:NetServiceBrowser, didRemove service: NetService, moreComing: Bool)
  {
    if debugOutput { print("didRemove '\(service.name)' domain:\(service.domain), hostname:\(service.hostName ?? "<none>") - \(moreComing ? "more coming" : "all done")") }
    services.remove(service)
    if !moreComing {
      refreshTable()
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
      refreshTable()
      pendingResolves = 0
    }
  }


  func netService(_ service: NetService, didNotResolve errorDict: [String : NSNumber])
  {
    if debugOutput { print("netService '\(service.name)' didNotResolve error:\(errorDict)") }
    services.remove(service)
    if pendingResolves <= 0 {
      refreshTable()
      pendingResolves = 0
    }
  }


  // MARK: ==== Updating Table



  func refreshTable()
  {
    sortedServices = services.sorted(by: { $0.name.caseInsensitiveCompare($1.name) == .orderedDescending });
    tableView.reloadData();
  }


  // MARK: ==== UITableViewDataSource / UITableViewDelegate


  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
  {
    if section == 0 { return sortedServices.count }
    else { return 0 }
  }


  // create a cell for each table view row
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    // create a new cell if needed or reuse an old one
    let cell:UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as UITableViewCell!
  
    // set the text from the data model
    cell.textLabel?.text = self.sortedServices[indexPath.row].name

    return cell
  }


  // method to run when table view cell is tapped
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let service = self.sortedServices[indexPath.row]
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
      if let url = URL(string: "http://" + hostname + ":" + String(service.port) + path) {
        // use system default browser
        if debugOutput { print("have default browser open '\(url)'") }
        UIApplication.shared.open(url)
      }
    }
  }


}

