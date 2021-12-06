//
//  Model.swift
//  Downloader
//
//  Created by Chris Eidhof on 15.11.21.
//

import Foundation

@MainActor
final class DownloadModel: ObservableObject, Sendable, AsyncDownloadDelegate {
    let url: URL
    init(_ url: URL) {
        self.url = url
    }
    
    enum State {
        case notStarted
        case started
        case paused(resumeData: Data?)
        case done(URL)
    }
    
    @Published var progress: (bytesWritten: Int64, bytesExpected: Int64)?
    
    @Published var state = State.notStarted
    
    private var downloadTask: URLSessionDownloadTask?
    private var delegate = DownloadModelDelegate()
    
    func start() {
        let task: URLSessionDownloadTask
        if case let .paused(data?) = state {
            task = URLSession.shared.downloadTask(withResumeData: data)
        } else {
            task = URLSession.shared.downloadTask(with: url)
        }
        state = .started
        delegate.delegate = self
        task.delegate = delegate
        task.resume()
        downloadTask = task
    }
    
    func pause() {
        Task {
            let data = await downloadTask?.cancelByProducingResumeData()
            state = .paused(resumeData: data)
        }
    }
    
    func didFinishDownloading(location: URL) async {
        state = .done(location)
    }
    
    func didWrite(bytesWritten: Int64, bytesExpected: Int64) async {
        progress = (bytesWritten, bytesExpected)
    }
}

protocol AsyncDownloadDelegate: AnyObject {
    func didFinishDownloading(location: URL) async
    func didWrite(bytesWritten: Int64, bytesExpected: Int64) async
}

final class DownloadModelDelegate: NSObject, URLSessionDownloadDelegate {
    weak var delegate: AsyncDownloadDelegate?
        
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task {
            await delegate?.didFinishDownloading(location: location)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task {
            await delegate?.didWrite(bytesWritten: totalBytesWritten, bytesExpected: totalBytesExpectedToWrite)
        }
    }
}
