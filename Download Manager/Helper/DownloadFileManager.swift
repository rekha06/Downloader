//
//  DownloadFileManager.swift
//  Downloader
//
//  Created by Rekha Ranjan on 6/5/20.
//  Copyright © 2020 Rekha Ranjan. All rights reserved.
//

import Foundation


class DownloadFileManager : NSObject, URLSessionDelegate, URLSessionDownloadDelegate {

    
   // static var shared = DownloadFileManager()
    
    var fileUrl : URL?

    typealias ProgressHandler = (Float) -> ()
    typealias CompletionHandler = (URL) -> ()
    
    var destinationFolder = FileManager.default.getDownloadsFolder()

    var onProgress : ProgressHandler? {
        didSet {
            if onProgress != nil {
                let _ = activate()
            }
        }
    }
    
    var onCompletion : CompletionHandler?
    
    var url : URL?
    var urlSession : URLSession?
    var task : URLSessionDownloadTask?
    var isDownloading = false
    
    convenience init(url: URL) {
        self.init()
        self.url = url
        self.activate()
    }

    func activate() {
        let config = URLSessionConfiguration.background(withIdentifier: "\(Date().millisecondsSince1970 ).background")

        // Warning: If an URLSession still exists from a previous download, it doesn't create a new URLSession object but returns the existing one with the old delegate object attached!
        self.urlSession =  URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }
    
    func download() {
        if let url = self.url, let session = urlSession {
            self.task =  session.downloadTask(with: url)
        }
        isDownloading = true
        self.task?.resume()
    }
    

    private func calculateProgress(session : URLSession, completionHandler : @escaping (Float) -> ()) {
        session.getTasksWithCompletionHandler { (tasks, uploads, downloads) in
            let progress = downloads.map({ (task) -> Float in
                if task.countOfBytesExpectedToReceive > 0 {
                    return Float(task.countOfBytesReceived) / Float(task.countOfBytesExpectedToReceive)
                } else {
                    return 0.0
                }
            })
            completionHandler(progress.reduce(0.0, +))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {

        if totalBytesExpectedToWrite > 0 {
            if let onProgress = onProgress {
                calculateProgress(session: session, completionHandler: onProgress)
            }
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            debugPrint("Progress \(downloadTask) \(progress)")

        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        isDownloading = false
        debugPrint("Download finished: \(location)")
        do {
            let manager = FileManager.default
            let destinationURL = self.getFileUrl(file: downloadTask.originalRequest!.url!.lastPathComponent)
            try manager.moveItem(at: location, to: destinationURL)
            self.fileUrl = destinationURL
            if let url = self.fileUrl {
                self.onCompletion?(url)
            }
        } catch {
            print("\(error)")
        }
        
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isDownloading = false
        debugPrint("Task completed: \(task), error: \(error)")
    }
    
    func getFileUrl(file: String) -> URL {
        let manager = FileManager.default
        var fileExists = true
        var fileCount = 0
        let defaultDestination = destinationFolder.appendingPathComponent(file)
        var destinationURL = defaultDestination
        while fileExists {
            if manager.fileExists(atPath: destinationURL.path) {
                fileCount += 1
               destinationURL = destinationFolder.appendingPathComponent("\(defaultDestination.deletingPathExtension().lastPathComponent)(\(fileCount)).\(defaultDestination.pathExtension)")
            }else {
                fileExists = false
            }
        }
        return destinationURL
    }
    
}

 

extension  FileManager {
    public func getDownloadsFolder()  -> URL {
        // path to documents directory
        let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        let downloadsDirectoryPath = documentDirectoryPath?.appending("/Downloads")
        if let downloadPath = downloadsDirectoryPath {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: downloadPath) {
                do {
                    try fileManager.createDirectory(atPath: downloadPath,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
                } catch {
                    print("Error creating images folder in documents dir: \(error)")
                }
            }
        }
        
        return URL(fileURLWithPath: downloadsDirectoryPath ?? "", isDirectory: true)
    }
}


extension Date {
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
