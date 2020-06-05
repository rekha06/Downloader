//
//  ViewController.swift
//  Download Manager
//
//  Created by Rekha on 05/06/20.
//  Copyright © 2020 Rekha. All rights reserved.
//

import UIKit
import AVKit

struct Downloads {
    var url : URL?
    var fileName : String?
    var formatName : String?
    
    static func load() -> [Downloads] {
        let directoryContents = try? FileManager.default.contentsOfDirectory(at: FileManager.default.getDownloadsFolder(), includingPropertiesForKeys: nil, options: [])
        return directoryContents?.compactMap({ (url) -> Downloads in
            return Downloads(url: url, fileName: url.deletingPathExtension().lastPathComponent, formatName: url.pathExtension)
        }) ?? []
    }
    static func loadFrom(url:URL) -> Downloads{
        return Downloads(url: url, fileName: url.deletingPathExtension().lastPathComponent, formatName: url.pathExtension)
    }
}

class ViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    var onGoingDownloads    =  [DownloadFileManager]()
    var completedDownloads  =  [Downloads]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.title = "Downloads"
        self.completedDownloads = Downloads.load()
        self.tableView.tableFooterView = UIView()
    }

    @IBAction func addDownload(_ sender: Any) {
        let alert = UIAlertController(title: "Enter Url", message: "Please enter valid file url to download", preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Enter url"
        }
        alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { (_) in
             self.startDownload(alert.textFields?[0].text)
        }))
        alert.addAction(UIAlertAction(title: "Discard", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    fileprivate func startDownload(_ urlText: String?) {
        var url: URL?
        if urlText?.verifyUrl() ?? false {
            url = URL(string: urlText ?? "")
        }
        guard let urlDownload = url, urlDownload.pathExtension.count > 0 else {
          self.showError(text: "Invalid download url")
          return
        }
        
        let downloadManager = DownloadFileManager(url: urlDownload)
        downloadManager.download()
        onGoingDownloads.insert(downloadManager, at: 0)
        self.tableView.reloadData()
        
    }
    
}



extension ViewController: UITableViewDelegate,UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        var count = 0
        if self.onGoingDownloads.count > 0 {
            count += 1
        }
        
        if self.completedDownloads.count > 0 {
                   count += 1
        }
        
        return count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && onGoingDownloads.count > 0 {
            return "Downloading"
        }else if completedDownloads.count > 0 {
             return "Downloaded Files"
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = 0
        if section == 0 && onGoingDownloads.count > 0 {
                   count = onGoingDownloads.count
        }else if completedDownloads.count > 0 {
                   count = completedDownloads.count
        }
        
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell =  tableView.dequeueReusableCell(withIdentifier: "cell") as? DownloadCell else {
             return UITableViewCell()
        }
        
        if indexPath.section == 0 && onGoingDownloads.count > 0 {
            cell.setupDownloadLayer()
               let downloading = self.onGoingDownloads[indexPath.row]
            cell.setupDownloadLayer()
            downloading.onProgress = {  val in
                DispatchQueue.main.async {
                    cell.downloadProgress.strokeEnd = CGFloat(val)
                }
            }
            downloading.onCompletion  = {[weak self] url in
                DispatchQueue.main.async {
                    self?.onGoingDownloads.remove(at: indexPath.row)
                    self?.completedDownloads.insert(Downloads.loadFrom(url: url), at: 0)
                    self?.tableView.reloadData()
                }
            }
            cell.title.text = downloading.url?.deletingPathExtension().lastPathComponent
            cell.format.text = downloading.url?.pathExtension.uppercased()
            
        }else if completedDownloads.count > 0 {
            cell.removeDownloadLayer()
            cell.circle.layer.cornerRadius = cell.circle.frame.width / 2
            cell.circle.layer.borderWidth = 4
            cell.circle.layer.borderColor = UIColor(red: 235/255, green: 69/255, blue: 89/255, alpha: 1).cgColor
            let file = self.completedDownloads[indexPath.row]
            cell.title.text = file.fileName
            cell.format.text = file.formatName?.uppercased()
            
        }
        
        return cell
       
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
          if indexPath.section == 0 && onGoingDownloads.count > 0 {
            self.showError(text: "File is downloading")
                  
          }else if completedDownloads.count > 0 {
            let file = self.completedDownloads[indexPath.row].url
            if let url = file, url.isVideoAudio() {
                let player = AVPlayer(url: url)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                self.present(playerViewController, animated: true) {
                    playerViewController.player!.play()
                }
            }else if let pdf = file, pdf.pathExtension == "pdf" {
                let document = PDFDocument(url: pdf)!
                let readerController = PDFViewController.createNew(with: document)
                self.navigationController?.pushViewController(readerController, animated: true)
            }else if let image = file, image.isImage() {
                let imageInfo = JTSImageInfo()
                imageInfo.imageURL = image
                imageInfo.referenceRect = tableView.frame
                imageInfo.referenceView = tableView
                
                let imageViewer = JTSImageViewController(imageInfo: imageInfo, mode: .image, backgroundStyle: .blurred)
                imageViewer?.show(from: self, transition: .fromOffscreen)
            }else {
                self.showError(text: "Unsupported format")
            }
              
          }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }
    
    
}


extension UIViewController {
    
    func showError(text: String) {
        let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
}

extension String {
    func verifyUrl () -> Bool {
         if let url = NSURL(string: self) {
            return UIApplication.shared.canOpenURL(url as URL)
         }
        
        return false
    }
}


class DownloadCell: UITableViewCell {
    
    var downloadProgress : CAShapeLayer!
    var trackLayer : CAShapeLayer!
    
    @IBOutlet weak var circle: UIView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var format: UILabel!
    
    
    func removeDownloadLayer() {
        if downloadProgress != nil {
             self.downloadProgress.removeFromSuperlayer()
        }
        if trackLayer != nil {
            self.trackLayer.removeFromSuperlayer()
        }
        self.downloadProgress = nil
        self.trackLayer = nil
    }
    func setupDownloadLayer() {
        circle.layer.borderColor = UIColor.clear.cgColor
        circle.layer.cornerRadius = 0
        circle.layer.borderWidth = 0
        guard downloadProgress == nil && trackLayer == nil else {
           return
        }
       let centerPoint = CGPoint (x: circle.bounds.width / 2, y: circle.bounds.width / 2)
        let circleRadius : CGFloat = circle.bounds.width / 2 * 0.83

        var circlePath = UIBezierPath(arcCenter: centerPoint, radius: circleRadius, startAngle: CGFloat(-0.5 * M_PI), endAngle: CGFloat(1.5 * M_PI), clockwise: true    )

        downloadProgress = CAShapeLayer()
        downloadProgress.path = circlePath.cgPath
        downloadProgress.strokeColor = UIColor(red: 235/255, green: 69/255, blue: 89/255, alpha: 1).cgColor
        downloadProgress.fillColor = UIColor.clear.cgColor
        downloadProgress.lineWidth = 4
        downloadProgress.strokeStart = 0
        downloadProgress.strokeEnd = 0.22

        circle.layer.addSublayer(downloadProgress)
    }
}


extension URL {

    public func isImage() -> Bool {
        // Add here your image formats.
        let imageFormats = ["jpg", "jpeg", "png", "gif"]
        return imageFormats.contains(self.pathExtension)
    }
    
    public func isVideoAudio() -> Bool {
        // Add here your image formats.
        let imageFormats = ["mp3", "mov", "mp4", "3gp","m4v","flv"]
         return imageFormats.contains(self.pathExtension)
    }

}
