//
//  AIService.swift
//  Code
//
//  AI service for communicating with NVIDIA API
//

import Foundation
import Combine

@MainActor
class AIService: ObservableObject {
    @Published var isLoading = false
    @Published var error: AIServiceError?
    
    private let apiURL = "https://integrate.api.nvidia.com/v1/chat/completions"
    private let authToken = "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"
    private let model = "moonshotai/kimi-k2-instruct"
    
    // System prompt for NeuralQuantum SWE Agent
    private let systemPrompt = """
Title: NeuralQuantum SWE Agent (Full-Stack, Agentic, Vertical-Slice SaaS Builder)
Persona: Senior full-stack SWE & AI strategist with end-to-end delivery focus.
Mission: Given a product brief or feature request, autonomously plan and ship a runnable SaaS vertical slice (AI, backend, frontend, infra) with various features (marketing, auth, subscriptions, marketplace, admin affordances, docs, tests, CI).
"""
    
    func sendMessage(_ userMessage: String, conversationHistory: [ChatMessage] = []) async throws -> AsyncThrowingStream<String, Error> {
        isLoading = true
        error = nil
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        // Prepare messages with system prompt and conversation history
        var messages = [ChatMessage(role: .system, content: systemPrompt)]
        messages.append(contentsOf: conversationHistory)
        messages.append(ChatMessage(role: .user, content: userMessage))
        
        let request = AIAPIRequest(
            model: model,
            messages: messages.map { APIMessage(from: $0) },
            temperature: 0.6,
            top_p: 0.9,
            frequency_penalty: 0,
            presence_penalty: 0,
            max_tokens: 4096,
            stream: true
        )
        
        return try await streamResponse(request: request)
    }
    
    private func streamResponse(request: AIAPIRequest) async throws -> AsyncThrowingStream<String, Error> {
        guard let url = URL(string: apiURL) else {
            throw AIServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIServiceError.networkError(URLError(.badServerResponse)))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: AIServiceError.apiError("HTTP \(httpResponse.statusCode)"))
                        return
                    }
                    
                    var buffer = ""
                    
                    for try await byte in asyncBytes {
                        let char = Character(UnicodeScalar(byte)!)
                        buffer.append(char)
                        
                        // Process complete lines
                        while let newlineIndex = buffer.firstIndex(of: "\n") {
                            let line = String(buffer[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = String(buffer[buffer.index(after: newlineIndex)...])
                            
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))
                                
                                if jsonString == "[DONE]" {
                                    continuation.finish()
                                    return
                                }
                                
                                if let data = jsonString.data(using: .utf8) {
                                    do {
                                        let response = try JSONDecoder().decode(AIAPIResponse.self, from: data)
                                        if let content = response.choices?.first?.delta?.content {
                                            continuation.yield(content)
                                        }
                                    } catch {
                                        // Continue processing other chunks even if one fails
                                        print("Failed to decode chunk: \(error)")
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AIServiceError.networkError(error))
                }
            }
        }
    }
    
    func clearError() {
        error = nil
    }
}