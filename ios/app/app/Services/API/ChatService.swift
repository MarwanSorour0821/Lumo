import Foundation

// Chat message model shared with the chat UI
struct ChatMessageDTO: Codable, Identifiable {
    let id: Int
    let role: String
    let content: String
    let message_type: String
    let file_name: String?
    let file_size: Int?
    let created_at: String

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case message_type
        case file_name
        case file_size
        case created_at
    }
}

struct ChatFileResult: Codable {
    let response: String?
}

actor ChatService {
    static let shared = ChatService()

    private init() {}

    func getChatHistory(userId: String) async throws -> [ChatMessageDTO] {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/chat/history/") else {
            return []
        }

        let accessToken = try await AuthService.shared.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST" // backend ChatHistoryView expects POST
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_id": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ChatService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load chat history: \(txt)"])
        }

        // Backend returns { success: true, messages: [...] }
        let decoder = JSONDecoder()
        do {
            struct Wrapper: Decodable {
                let success: Bool
                let messages: [ChatMessageDTO]?
            }
            let wrapped = try decoder.decode(Wrapper.self, from: data)
            return wrapped.messages ?? []
        } catch {
            // log raw response for debugging
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("🔴 ChatService.getChatHistory: failed to decode response - raw=\(raw), error=\(error)")
            return []
        }
    }

    func sendChatMessage(userId: String, message: String) async throws -> String {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/chat/send/") else {
            throw NSError(domain: "ChatService", code: 2, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }

        let accessToken = try await AuthService.shared.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_id": userId, "message": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ChatService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Send failed: \(txt)"])
        }

        // Try to decode { response: "..." }
        if let decoded = try? JSONDecoder().decode([String: String].self, from: data), let resp = decoded["response"] {
            return resp
        }

        if let decoded = try? JSONDecoder().decode(ChatFileResult.self, from: data), let resp = decoded.response {
            return resp
        }

        // Fallback to raw string
        return String(data: data, encoding: .utf8) ?? ""
    }

    func sendChatFile(userId: String, fileUrl: URL, fileName: String, mimeType: String, message: String?) async throws -> ChatFileResult {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/chat/send-file/") else {
            throw NSError(domain: "ChatService", code: 4, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }

        let accessToken = try await AuthService.shared.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "----LumoBoundary\(UUID().uuidString)"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendFormField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendFormField(name: "user_id", value: userId)
        if let msg = message { appendFormField(name: "message", value: msg) }

        // file part
        let fileData = try Data(contentsOf: fileUrl)
        print("📤 Uploading file: \(fileName), size: \(fileData.count) bytes, mimeType: \(mimeType)")
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        let disposition = "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n"
        body.append(disposition.data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        print("📤 Request body size: \(body.count) bytes")
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("📥 Response status: \(http.statusCode)")
        
        guard (200...299).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8) ?? ""
            print("❌ File upload failed with status \(http.statusCode): \(txt)")
            throw NSError(domain: "ChatService", code: 5, userInfo: [NSLocalizedDescriptionKey: "File upload failed: \(txt)"])
        }

        let decoder = JSONDecoder()
        if let result = try? decoder.decode(ChatFileResult.self, from: data) {
            return result
        }

        // Try decoding as { response: "..." }
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return ChatFileResult(response: dict["response"])
        }

        return ChatFileResult(response: String(data: data, encoding: .utf8))
    }
    
    /// Send a chat message with analysis context for blood test questions
    func sendChatMessageWithContext(userId: String, message: String, analysisContext: String) async throws -> String {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/chat/send/") else {
            throw NSError(domain: "ChatService", code: 2, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }

        let accessToken = try await AuthService.shared.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include the analysis context in the message so the AI has full context
        let contextualMessage = """
        [Blood Test Analysis Context]
        \(analysisContext)
        
        [User Question]
        \(message)
        """
        
        let body: [String: Any] = ["user_id": userId, "message": contextualMessage]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ChatService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Send failed: \(txt)"])
        }

        // Try to decode { response: "..." }
        if let decoded = try? JSONDecoder().decode([String: String].self, from: data), let resp = decoded["response"] {
            return resp
        }

        if let decoded = try? JSONDecoder().decode(ChatFileResult.self, from: data), let resp = decoded.response {
            return resp
        }

        // Fallback to raw string
        return String(data: data, encoding: .utf8) ?? ""
    }
}
