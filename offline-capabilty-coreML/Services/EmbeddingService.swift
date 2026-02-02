//
//  EmbeddingService.swift
//  OfflineSemanticSearch
//
//  Created by macbook pro on 01/02/26.
//

import Foundation
import CoreML

final class EmbeddingService {

    static let shared = EmbeddingService()

    private let model = try! MiniLMEmbedding(configuration: MLModelConfiguration())

    func embed(text: String) -> [Float] {
        let tokens = tokenize(text)
        guard let inputIDs = createMLMultiArray(from: tokens),
              let attentionMask = createAttentionMask(for: tokens) else {
            return []
        }

        let input = MiniLMEmbeddingInput(input_ids: inputIDs, attention_mask: attentionMask)

        guard let output = try? model.prediction(input: input) else {
            return []
        }

        return mlMultiArrayToFloatArray(output.embedding)
    }

    // Converts MLMultiArray output to [Float]
    private func mlMultiArrayToFloatArray(_ mlArray: MLMultiArray) -> [Float] {
        let pointer = UnsafeMutablePointer<Float>(OpaquePointer(mlArray.dataPointer))
        let count = mlArray.count
        let buffer = UnsafeBufferPointer(start: pointer, count: count)
        return Array(buffer)
    }

    // Creates MLMultiArray from [Int32] tokens
    private func createMLMultiArray(from tokens: [Int32]) -> MLMultiArray? {
        guard let mlArray = try? MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32) else {
            return nil
        }

        for (index, token) in tokens.enumerated() {
            mlArray[[0, NSNumber(value: index)]] = NSNumber(value: token)
        }
        return mlArray
    }

    // Creates attention mask MLMultiArray from tokens (0 for padding tokens, 1 otherwise)
    private func createAttentionMask(for tokens: [Int32]) -> MLMultiArray? {
        guard let maskArray = try? MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32) else {
            return nil
        }

        for (index, token) in tokens.enumerated() {
            maskArray[[0, NSNumber(value: index)]] = NSNumber(value: token == 0 ? 0 : 1)
        }
        return maskArray
    }

    // Simple tokenizer — replace with actual tokenizer if needed
    private func tokenize(_ text: String, maxLength: Int = 128) -> [Int32] {
        let words = text.lowercased().split(separator: " ")
        var tokens = words.map { _ in Int32.random(in: 100...10000) }

        if tokens.count > maxLength {
            tokens = Array(tokens.prefix(maxLength))
        }

        while tokens.count < maxLength {
            tokens.append(0)
        }
        return tokens
    }
}

