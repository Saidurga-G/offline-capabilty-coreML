//
//  PDFLoader.swift
//  OfflineSemanticSearch
//
//  Created by macbook pro on 01/02/26.
//

import PDFKit
import UIKit

final class PDFLoader {

    static func loadAllPDFText() -> [String] {
        guard let pdfURLs = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil) else {
            return []
        }

        var chunks: [String] = []

        for url in pdfURLs {
            guard let doc = PDFDocument(url: url) else { continue }

            for index in 0..<doc.pageCount {
                guard let page = doc.page(at: index) else { continue }

                // 1️⃣ Use embedded text if available
                if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chunks.append(text)
                    continue   
                }

                // 2️⃣ OCR only if needed
                let image = page.thumbnail(
                    of: CGSize(width: 600, height: 600),
                    for: .mediaBox
                )

                let ocrText = OCRService.recognizeText(from: image)
                if !ocrText.isEmpty {
                    chunks.append(ocrText)
                }
            }
        }

        return chunks
    }
}
