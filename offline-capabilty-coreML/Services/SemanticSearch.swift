//
//  SemanticSearch.swift
//  OfflineSemanticSearch
//
//  Created by macbook pro on 01/02/26.
//

import Foundation

final class SemanticSearch {

    static let shared = SemanticSearch()
    private var indexed = false

    // MARK: - Public Search API

    func search(query: String) -> String {

        print("🔍 Search started")

        if !indexed {
            print("📚 Indexing documents...")
            indexDocuments()
            indexed = true
            print("✅ Indexing complete")
        }

        print("🧠 Creating query embedding")
        let queryEmbedding = EmbeddingService.shared.embed(text: query)

        guard !queryEmbedding.isEmpty else {
            return "Failed to create query embedding"
        }

        let results = SQLiteVectorStore.shared.semanticSearch(
            queryEmbedding: queryEmbedding,
            topK: 3
        )

        print("Results count:", results.count)

        guard let best = results.first,
              !best.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No relevant answer found"
        }

        print("Best score:", best.score)
        print("Source:", best.source)

        return String(best.text.prefix(500))
    }

    // MARK: - Indexing

    private func indexDocuments() {

        let documents = PDFLoader.loadAllPDFText()
        print("📄 PDFs loaded:", documents.count)

        for (index, text) in documents.enumerated() {

            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count > 50 else { continue }

            let embedding = EmbeddingService.shared.embed(text: cleaned)
            guard !embedding.isEmpty else { continue }

            SQLiteVectorStore.shared.insert(
                source: "pdf_\(index)",
                text: cleaned,
                embedding: embedding
            )
        }
    }
}

