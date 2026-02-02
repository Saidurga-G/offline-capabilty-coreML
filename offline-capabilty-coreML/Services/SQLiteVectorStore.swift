import Foundation
import SQLite3
import Accelerate

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteVectorStore {

    static let shared = SQLiteVectorStore()
    private var db: OpaquePointer?

    private init() {
        openDB()
        createTable()
    }

    // MARK: - DB Setup

    private func openDB() {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VectorStore.sqlite")

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            print("❌ Failed to open database")
        }
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS vectors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source TEXT,
            text TEXT,
            embedding BLOB
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - Insert

    func insert(source: String, text: String, embedding: [Float]) {
        let sql = "INSERT INTO vectors (source, text, embedding) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?

        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)

        sqlite3_bind_text(stmt, 1, source, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, text, -1, SQLITE_TRANSIENT)

        embedding.withUnsafeBytes { buffer in
            sqlite3_bind_blob(
                stmt,
                3,
                buffer.baseAddress,
                Int32(buffer.count),
                SQLITE_TRANSIENT
            )
        }

        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // MARK: - Fetch All

    private func fetchAll() -> [(source: String, text: String, embedding: [Float])] {
        var result: [(String, String, [Float])] = []

        let sql = "SELECT source, text, embedding FROM vectors"
        var stmt: OpaquePointer?

        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)

        while sqlite3_step(stmt) == SQLITE_ROW {

            let source = String(cString: sqlite3_column_text(stmt, 0))
            let text = String(cString: sqlite3_column_text(stmt, 1))

            let blob = sqlite3_column_blob(stmt, 2)
            let size = Int(sqlite3_column_bytes(stmt, 2))   // ✅ FIX
            let count = size / MemoryLayout<Float>.size

            let buffer = blob!.bindMemory(to: Float.self, capacity: count)

            let embedding: [Float] = Array(                // ✅ FIX
                UnsafeBufferPointer<Float>(start: buffer, count: count)
            )

            result.append((source, text, embedding))
        }

        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - Semantic Search

    func semanticSearch(
        queryEmbedding: [Float],
        topK: Int = 5
    ) -> [(score: Float, source: String, text: String)] {

        let all = fetchAll()

        var scored: [(Float, String, String)] = all.map { row in
            let score = cosineSimilarity(queryEmbedding, row.embedding)
            return (score, row.source, row.text)
        }

        scored.sort { (a: (Float, String, String),
                        b: (Float, String, String)) in
            a.0 > b.0                                     // ✅ FIX
        }

        return scored.prefix(topK).map {
            (score: $0.0, source: $0.1, text: $0.2)
        }
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        return dot / (sqrt(normA) * sqrt(normB) + 1e-8)
    }
}

