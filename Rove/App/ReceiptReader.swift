import Foundation
import UIKit
import Vision

/// Finds the text on a receipt photo or screenshot with the phone's own text
/// recognition. Nothing leaves the phone, and the picture is dropped as soon
/// as the lines are read; only the details the person confirms are saved.
enum ReceiptReader {
    enum Failure: Error { case notAnImage }

    static func lines(in imageData: Data) async throws -> [String] {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { throw Failure.notAnImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
                    continuation.resume(returning: ordered(request.results ?? []))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Joins pieces of text on the same printed row ("Total" ... "50.18"),
    /// top to bottom, left to right.
    private static func ordered(_ observations: [VNRecognizedTextObservation]) -> [String] {
        let pieces = observations.compactMap { observation -> (box: CGRect, text: String)? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return (observation.boundingBox, text)
        }
        // Vision's boxes start at the bottom left; higher y is nearer the top.
        let sorted = pieces.sorted { $0.box.midY > $1.box.midY }
        var rows: [[(box: CGRect, text: String)]] = []
        for piece in sorted {
            if let last = rows.last?.first, abs(last.box.midY - piece.box.midY) < max(last.box.height, piece.box.height) * 0.5 {
                rows[rows.count - 1].append(piece)
            } else {
                rows.append([piece])
            }
        }
        return rows.map { row in row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
