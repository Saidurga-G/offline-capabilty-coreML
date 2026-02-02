//
//  OCRService.swift
//  OfflineSemanticSearch
//
//  Created by macbook pro on 01/02/26.
//

import Foundation
import Vision
import UIKit

final class OCRService {

    static func recognizeText(from image: UIImage) -> String {
        guard let cgImage = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        return request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""
    }
}
