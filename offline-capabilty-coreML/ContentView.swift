//
//  ContentView.swift
//  OfflineSemanticSearch
//
//  Created by macbook pro on 01/02/26.
//

import SwiftUI

struct ContentView: View {

    @State private var query = ""
    @State private var answer = "Ask a question about your PDFs (offline)"
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 16) {

            Text("Offline Semantic Search")
                .font(.title2)
                .bold()

            TextField("Enter your question", text: $query)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .onChange(of: query) { newValue in
                    if newValue.isEmpty {
                        answer = "Ask a question about your PDFs (offline)"
                    }
                }

            Button {
                performSearch()
            } label: {
                if isSearching {
                    ProgressView()
                } else {
                    Text("Search").bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(query.isEmpty || isSearching)

            ScrollView {
                Text(answer)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Async Search Wrapper (IMPORTANT)
    private func performSearch() {
        guard !query.isEmpty else { return }

        isSearching = true
        answer = "Searching…"

        Task.detached(priority: .userInitiated) {
            let result = await SemanticSearch.shared.search(query: query)

            await MainActor.run {
                self.answer = result
                self.isSearching = false
            }
        }
    }
}

#Preview {
    ContentView()
}
