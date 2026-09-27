import NIOCore
import XCTest

@testable import speech_server

final class DetectedAudioFileWriterTests: XCTestCase {
    func testWaitsForCompleteHeaderAndUsesContentOverFilename() throws {
        let adtsHeader = Data([0xFF, 0xF1, 0x50, 0x80, 0x01, 0x7F, 0xFC, 0x00, 0x00, 0x00, 0x00, 0x00])
        let payload = Data([0x11, 0x22, 0x33])
        let writer = DetectedAudioFileWriter(filename: "voice-note.m4a")
        defer { writer.cleanup() }

        for byte in adtsHeader.prefix(11) {
            writer.append(ByteBuffer(bytes: [byte]))
        }
        XCTAssertNil(writer.fileURL)

        writer.append(ByteBuffer(bytes: [adtsHeader[11]]))
        writer.append(ByteBuffer(data: payload))
        writer.finish()
        try writer.throwIfFailed()

        let url = try XCTUnwrap(writer.fileURL)
        XCTAssertEqual(url.pathExtension, "aac")
        XCTAssertEqual(try Data(contentsOf: url), adtsHeader + payload)
        XCTAssertEqual(writer.byteCount, adtsHeader.count + payload.count)
    }
}
