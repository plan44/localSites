//
//  ViewController.swift
//  iosLocalSites
//
//  Created by Lukas Zeller on 19.08.18.
//  Copyright © 2018 plan44.ch. All rights reserved.
//

import UIKit

class SitesTableController: UITableViewController, NetServiceBrowserDelegate, NetServiceDelegate {

  @IBOutlet weak var noSitesLabel: UILabel!
  let debugOutput = true

  var netServiceBrowsers: [NetServiceBrowser] = []

  let domainToBrowse = ""
  let servicesToBrowse = ["_http._tcp.", "_https._tcp.", "_http-alt._tcp."]

  var services: Set<NetService> = Set();
  var sortedServices: [NetService] = Array();

  var pendingResolves = 0;

  // cell reuse id (cells that scroll out of view can be reused)
  let cellReuseIdentifier = "localSiteCell"


  func restartSearch()
  {
    netServiceBrowsers.forEach { $0.stop() }
    services.removeAll()
    netServiceBrowsers.removeAll()
    // Note: on iOS, the only way to make this work seems to be passing empty string to inDomain:
    //   And NOT using searchForBrowsableDomains() -> didFindDomain:
    // - start network service search
    servicesToBrowse.forEach {
      let netServiceBrowser = NetServiceBrowser()
      netServiceBrowser.delegate = self
      netServiceBrowser.searchForServices(ofType: $0, inDomain: domainToBrowse)
      netServiceBrowsers.append(netServiceBrowser) // retain!
    }
  }


  @objc func didBecomeActive(_ notification:Notification)
  {
    restartSearch();
  }


  override func viewDidLoad() {
    super.viewDidLoad()
    // - observe global app did become active event
    NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    // - start network service search
    restartSearch();
  }


  deinit
  {
    NotificationCenter.default.removeObserver(self);
  }


  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


  // MARK: ==== NetServiceBrowser delegate

  func netServiceBrowser(_: NetServiceBrowser , didFind service: NetService, moreComing: Bool) {
    if debugOutput { print("didFind '\(service.name)', domain:\(service.domain), type:\(service.type), hostname:\(service.hostName ?? "<none>") - \(moreComing ? "more coming" : "all done")") }
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
    noSitesLabel.isHidden = services.count > 0
    sortedServices = services.sorted(by: { $0.name.caseInsensitiveCompare($1.name) == .orderedAscending });
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
    let cell:UITableViewCell = (self.tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as UITableViewCell?)!

    // set the text from the data model
    let service = self.sortedServices[indexPath.row]
    let typeComponents = service.type.components(separatedBy: ".")
    let scheme = typeComponents.first?.replacingOccurrences(of: "_", with: "") ?? "http"
    cell.textLabel?.text = "\(service.name) \(scheme=="https" ? "🔒" : (scheme=="http" ? "" : "[⚠️\(scheme)]"))";

    return cell
  }


  // method to run when table view cell is tapped
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let service = self.sortedServices[indexPath.row]
    if debugOutput { print("- '\(service.name)' [\(service.type)]'    -    '\(service.hostName ?? "<none>")'") }
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
        // use system default browser
        if debugOutput { print("have default browser open '\(url)'") }
        if #available(iOS 10.0, *) {
          UIApplication.shared.open(url)
        }
        else {
          UIApplication.shared.openURL(url)
        }
      }
    }
  }


}

