import Foundation
import NIOCore

/// Buffers enough uploaded audio to identify its format before creating the
/// extension-sensitive temporary file consumed by AVFoundation.
final class DetectedAudioFileWriter {
    let filename: String
    private(set) var fileURL: URL?
    private(set) var byteCount = 0

    private var pending = Data()
    private var fileHandle: FileHandle?
    private var failure: Error?

    init(filename: String) {
        self.filename = filename
    }

    func append(_ chunk: ByteBuffer) {
        guard failure == nil, chunk.readableBytes > 0 else { return }
        guard let data = chunk.getData(at: chunk.readerIndex, length: chunk.readableBytes) else {
            failure = DetectedAudioFileWriterError.unreadableChunk
            return
        }

        byteCount += data.count
        if fileHandle == nil {
            pending.append(data)
            openIfReady(force: false)
        }
        else {
            write(data)
        }
    }

    func finish() {
        openIfReady(force: true)
        do {
            try fileHandle?.close()
        }
        catch {
            failure = failure ?? error
        }
        fileHandle = nil
    }

    func throwIfFailed() throws {
        if let failure { throw failure }
    }

    func cleanup() {
        try? fileHandle?.close()
        fileHandle = nil
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
            self.fileURL = nil
        }
    }

    private func openIfReady(force: Bool) {
        guard failure == nil, fileHandle == nil, !pending.isEmpty else { return }
        guard pending.count >= 12 || force else { return }

        let ext = audioFileExtension(filename: filename, header: pending.prefix(12))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)\(ext)")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            failure = DetectedAudioFileWriterError.cannotCreateFile(url)
            return
        }
        fileURL = url

        do {
            let handle = try FileHandle(forWritingTo: url)
            fileHandle = handle
            write(pending)
            pending.removeAll()
        }
        catch {
            failure = error
        }
    }

    private func write(_ data: Data) {
        guard failure == nil, let fileHandle else { return }
        do {
            try fileHandle.write(contentsOf: data)
        }
        catch {
            failure = error
        }
    }
}

enum DetectedAudioFileWriterError: Error, CustomStringConvertible {
    case unreadableChunk
    case cannotCreateFile(URL)

    var description: String {
        switch self {
        case .unreadableChunk:
            return "Could not read an uploaded audio chunk."
        case .cannotCreateFile(let url):
            return "Could not create temporary audio file at \(url.path)."
        }
    }
}
