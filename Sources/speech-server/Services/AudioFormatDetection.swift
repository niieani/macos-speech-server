import Foundation
import Logging

private let logger: Logger = {
    var l = Logger(label: "AudioFormatDetection")
    l.logLevel = .notice
    return l
}()

/// Returns the correct file extension (with leading dot) for an audio file.
/// Uses magic-byte detection on the first 12 bytes of `header`; falls back to a
/// recognized filename extension only when the content is inconclusive.
func audioFileExtension(filename: String, header: Data) -> String {
    let knownExtensions: Set<String> = ["wav", "mp3", "m4a", "aac", "flac", "aiff", "ogg"]
    let ext = (filename as NSString).pathExtension.lowercased()

    if header.count >= 12 {
        let bytes = Array(header.prefix(12))

        // WAV: "RIFF" at 0, "WAVE" at 8
        if bytes[0...3] == [0x52, 0x49, 0x46, 0x46] && bytes[8...11] == [0x57, 0x41, 0x56, 0x45] {
            return ".wav"
        }
        // FLAC: "fLaC" at 0
        if bytes[0...3] == [0x66, 0x4C, 0x61, 0x43] {
            return ".flac"
        }
        // MP3: "ID3" at 0 or MPEG audio sync bytes.
        if bytes[0...2] == [0x49, 0x44, 0x33] {
            return ".mp3"
        }
        if bytes[0] == 0xFF && [0xFB, 0xF3, 0xF2, 0xFA].contains(bytes[1]) {
            return ".mp3"
        }
        // AAC/ADTS: 12-bit sync word, layer bits 00, protection bit arbitrary.
        if bytes[0] == 0xFF && (bytes[1] & 0xF6) == 0xF0 {
            return ".aac"
        }
        // M4A/MP4: "ftyp" at bytes 4–7
        if bytes[4...7] == [0x66, 0x74, 0x79, 0x70] {
            return ".m4a"
        }
        // OGG: "OggS" at 0
        if bytes[0...3] == [0x4F, 0x67, 0x67, 0x53] {
            return ".ogg"
        }
        // AIFF: "FORM" at 0, "AIFF"/"AIFC" at 8
        if bytes[0...3] == [0x46, 0x4F, 0x52, 0x4D]
            && (bytes[8...11] == [0x41, 0x49, 0x46, 0x46] || bytes[8...11] == [0x41, 0x49, 0x46, 0x43])
        {
            return ".aiff"
        }
    }

    if knownExtensions.contains(ext) {
        return ".\(ext)"
    }

    logger.warning("Could not detect audio format for '\(filename)'; defaulting to .wav")
    return ".wav"
}
