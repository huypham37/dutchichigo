import Foundation
import CoreData

/// AI-powered personalization engine using OpenAI GPT-4
class AIPersonalizationEngine {
    
    private let apiKey: String
    private let model: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // MARK: - Initialization
    
    init(apiKey: String, model: String = "gpt-4") {
        self.apiKey = apiKey
        self.model = model
    }
    
    // MARK: - Example Generation
    
    /// Generate personalized example sentence using known vocabulary
    func generatePersonalizedExample(
        dutchWord: String,
        englishTranslation: String,
        userProfile: UserProfile,
        knownVocabulary: [String]
    ) async throws -> ExampleSentenceData {
        
        let interests = userProfile.interests.isEmpty ? ["general"] : userProfile.interests
        let primaryInterest = interests.first ?? "general"
        let cefrLevel = userProfile.cefrLevelEnum.rawValue
        
        // Limit known vocabulary to prevent token overflow
        let vocabularyList = knownVocabulary.prefix(100).joined(separator: ", ")
        
        let prompt = """
        Generate a Dutch sentence using the word "\(dutchWord)" (\(englishTranslation)).
        
        Constraints:
        - Use only these known Dutch words: \(vocabularyList)
        - Match user interest: \(primaryInterest)
        - Keep sentence simple for CEFR level: \(cefrLevel)
        - Natural, conversational Dutch
        - Maximum 10 words
        
        Return JSON only:
        {
            "dutch": "sentence here",
            "english": "translation here"
        }
        """
        
        let response = try await callOpenAI(prompt: prompt, temperature: 0.7)
        return parseExampleSentence(response)
    }
    
    // MARK: - Mnemonic Generation
    
    /// Generate memorable mnemonic for vocabulary word
    func generateMnemonic(
        dutchWord: String,
        englishTranslation: String,
        isFalseFriend: Bool
    ) async throws -> String {
        
        if isFalseFriend {
            return try await generateFalseFriendMnemonic(
                dutchWord: dutchWord,
                englishTranslation: englishTranslation
            )
        }
        
        let prompt = """
        Create a memorable mnemonic for learning the Dutch word "\(dutchWord)" meaning "\(englishTranslation)".
        
        Guidelines:
        - Use sound associations, visual imagery, or funny stories
        - Keep it under 50 words
        - Make it vivid and memorable
        - Avoid anything offensive
        
        Return only the mnemonic text, no extra formatting.
        """
        
        return try await callOpenAI(prompt: prompt, temperature: 0.9)
    }
    
    /// Generate warning mnemonic for false friends
    private func generateFalseFriendMnemonic(
        dutchWord: String,
        englishTranslation: String
    ) async throws -> String {
        
        let prompt = """
        The Dutch word "\(dutchWord)" means "\(englishTranslation)" - NOT what it sounds like in English.
        This is a false friend.
        
        Create a memorable warning/mnemonic to help remember the CORRECT meaning.
        Make it catchy and memorable. Keep it under 50 words.
        
        Return only the mnemonic text.
        """
        
        return try await callOpenAI(prompt: prompt, temperature: 0.9)
    }
    
    // MARK: - Error Explanation
    
    /// Explain why user's answer was incorrect
    func explainError(
        card: VocabularyCard,
        userAnswer: String,
        correctAnswer: String
    ) async throws -> String {
        
        let prompt = """
        The user answered "\(userAnswer)" but the correct Dutch word is "\(correctAnswer)" for "\(card.englishTranslation)".
        
        Provide a brief, encouraging explanation:
        1. Why their answer was incorrect
        2. The key difference to remember
        3. A tip to avoid this mistake
        
        Keep it under 100 words, friendly tone, and encouraging.
        """
        
        return try await callOpenAI(prompt: prompt, temperature: 0.7)
    }
    
    // MARK: - Knowledge Gap Detection
    
    /// Analyze error patterns to detect systematic learning gaps
    func detectKnowledgeGaps(
        recentErrors: [ReviewRecord],
        vocabulary: [VocabularyCard]
    ) -> [KnowledgeGap] {
        var gaps: [KnowledgeGap] = []
        
        // Check for verb conjugation issues
        let verbErrors = recentErrors.filter { record in
            guard let card = vocabulary.first(where: { $0.id == record.card?.id }) else { return false }
            return card.wordTypeEnum == .verb && !record.wasCorrect
        }
        if verbErrors.count >= 5 {
            gaps.append(.verbConjugation)
        }
        
        // Check for de/het confusion
        let genderErrors = recentErrors.filter { record in
            guard let card = vocabulary.first(where: { $0.id == record.card?.id }) else { return false }
            return card.wordTypeEnum == .noun && !record.wasCorrect && card.genderEnum != nil
        }
        if genderErrors.count >= 3 {
            gaps.append(.articleGender)
        }
        
        // Check for false friend issues
        let falseFriendErrors = recentErrors.filter { record in
            guard let card = vocabulary.first(where: { $0.id == record.card?.id }) else { return false }
            return card.isFalseFriend && !record.wasCorrect
        }
        if falseFriendErrors.count >= 3 {
            gaps.append(.falseFriends)
        }
        
        return gaps
    }
    
    /// Generate targeted practice recommendations based on knowledge gaps
    func generateGapRecommendations(gaps: [KnowledgeGap]) async throws -> String {
        let gapDescriptions = gaps.map { gap in
            switch gap {
            case .verbConjugation: return "verb conjugation"
            case .articleGender: return "de/het article gender"
            case .wordOrder: return "word order"
            case .falseFriends: return "false friends"
            case .separableVerbs: return "separable verbs"
            }
        }.joined(separator: ", ")
        
        let prompt = """
        The user is struggling with: \(gapDescriptions) in Dutch.
        
        Provide 3 brief, actionable tips to improve in these areas.
        Keep each tip under 30 words. Be encouraging and specific.
        """
        
        return try await callOpenAI(prompt: prompt, temperature: 0.7)
    }
    
    // MARK: - OpenAI API
    
    /// Call OpenAI Chat Completions API
    private func callOpenAI(prompt: String, temperature: Double = 0.7) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful Dutch language tutor. Be concise and encouraging."],
                ["role": "user", "content": prompt]
            ],
            "temperature": temperature,
            "max_tokens": 300
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Response Parsing
    
    /// Parse JSON response for example sentence
    private func parseExampleSentence(_ response: String) throws -> ExampleSentenceData {
        // Remove markdown code blocks if present
        let cleanResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanResponse.data(using: .utf8) else {
            throw AIError.parseError
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ExampleSentenceData.self, from: data)
    }
}

// MARK: - Supporting Types

struct ExampleSentenceData: Codable {
    let dutch: String
    let english: String
}

enum AIError: Error {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case parseError
    case rateLimitExceeded
}
