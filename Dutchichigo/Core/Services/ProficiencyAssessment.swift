import Foundation
import CoreData

/// Quick proficiency assessment using adaptive testing
class ProficiencyAssessment {
    
    private let context: NSManagedObjectContext
    private var testWords: [TestWord] = []
    private var currentIndex = 0
    private var correctCount = 0
    private var currentEstimatedLevel: CEFRLevel = .A1
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Test Setup
    
    /// Initialize proficiency test with stratified word selection
    func initializeTest() {
        testWords = [
            // A1 Level (10 words) - High frequency + cognates
            TestWord(dutch: "boek", english: "book", cefrLevel: .A1, frequencyRank: 100, isCognate: true),
            TestWord(dutch: "water", english: "water", cefrLevel: .A1, frequencyRank: 50, isCognate: true),
            TestWord(dutch: "dag", english: "day", cefrLevel: .A1, frequencyRank: 20, isCognate: false),
            TestWord(dutch: "huis", english: "house", cefrLevel: .A1, frequencyRank: 80, isCognate: false),
            TestWord(dutch: "eten", english: "to eat", cefrLevel: .A1, frequencyRank: 150, isCognate: false),
            TestWord(dutch: "goed", english: "good", cefrLevel: .A1, frequencyRank: 30, isCognate: false),
            TestWord(dutch: "groot", english: "big", cefrLevel: .A1, frequencyRank: 120, isCognate: false),
            TestWord(dutch: "klein", english: "small", cefrLevel: .A1, frequencyRank: 140, isCognate: false),
            TestWord(dutch: "man", english: "man", cefrLevel: .A1, frequencyRank: 60, isCognate: true),
            TestWord(dutch: "vrouw", english: "woman", cefrLevel: .A1, frequencyRank: 90, isCognate: false),
            
            // A2 Level (8 words)
            TestWord(dutch: "kleding", english: "clothing", cefrLevel: .A2, frequencyRank: 500, isCognate: false),
            TestWord(dutch: "betalen", english: "to pay", cefrLevel: .A2, frequencyRank: 450, isCognate: false),
            TestWord(dutch: "gezellig", english: "cozy/fun", cefrLevel: .A2, frequencyRank: 600, isCognate: false),
            TestWord(dutch: "lekker", english: "tasty/nice", cefrLevel: .A2, frequencyRank: 400, isCognate: false),
            TestWord(dutch: "boodschappen", english: "groceries", cefrLevel: .A2, frequencyRank: 550, isCognate: false),
            TestWord(dutch: "vergeten", english: "to forget", cefrLevel: .A2, frequencyRank: 480, isCognate: false),
            TestWord(dutch: "spijt", english: "regret", cefrLevel: .A2, frequencyRank: 520, isCognate: false),
            TestWord(dutch: "eigenlijk", english: "actually", cefrLevel: .A2, frequencyRank: 420, isCognate: false),
            
            // B1 Level (6 words)
            TestWord(dutch: "verbeteren", english: "to improve", cefrLevel: .B1, frequencyRank: 1200, isCognate: false),
            TestWord(dutch: "milieu", english: "environment", cefrLevel: .B1, frequencyRank: 1500, isCognate: false),
            TestWord(dutch: "ontwikkelen", english: "to develop", cefrLevel: .B1, frequencyRank: 1100, isCognate: false),
            TestWord(dutch: "bespreken", english: "to discuss", cefrLevel: .B1, frequencyRank: 1300, isCognate: false),
            TestWord(dutch: "mededeling", english: "announcement", cefrLevel: .B1, frequencyRank: 1400, isCognate: false),
            TestWord(dutch: "oplossing", english: "solution", cefrLevel: .B1, frequencyRank: 1250, isCognate: false),
            
            // B2 Level (4 words)
            TestWord(dutch: "beheersen", english: "to master", cefrLevel: .B2, frequencyRank: 2500, isCognate: false),
            TestWord(dutch: "achtergrond", english: "background", cefrLevel: .B2, frequencyRank: 2200, isCognate: false),
            TestWord(dutch: "weerspiegelen", english: "to reflect", cefrLevel: .B2, frequencyRank: 2800, isCognate: false),
            TestWord(dutch: "onderscheiden", english: "to distinguish", cefrLevel: .B2, frequencyRank: 2600, isCognate: false),
            
            // C1 Level (3 words)
            TestWord(dutch: "betreuren", english: "to regret", cefrLevel: .C1, frequencyRank: 4000, isCognate: false),
            TestWord(dutch: "toegeven", english: "to admit", cefrLevel: .C1, frequencyRank: 3800, isCognate: false),
            TestWord(dutch: "veronderstellen", english: "to assume", cefrLevel: .C1, frequencyRank: 4200, isCognate: false),
            
            // Pseudowords (for false alarm detection)
            TestWord(dutch: "flonker", english: "[fake]", cefrLevel: .A1, frequencyRank: 99999, isCognate: false),
            TestWord(dutch: "grimpen", english: "[fake]", cefrLevel: .A2, frequencyRank: 99999, isCognate: false),
            TestWord(dutch: "blompje", english: "[fake]", cefrLevel: .B1, frequencyRank: 99999, isCognate: false),
            TestWord(dutch: "drenksel", english: "[fake]", cefrLevel: .B2, frequencyRank: 99999, isCognate: false),
        ]
        
        // Shuffle to prevent pattern recognition
        testWords.shuffle()
        currentIndex = 0
        correctCount = 0
    }
    
    // MARK: - Test Evaluation
    
    /// Evaluate user's response
    func evaluateAnswer(userKnows: Bool) {
        guard currentIndex < testWords.count else { return }
        
        let currentWord = testWords[currentIndex]
        let isPseudoword = currentWord.frequencyRank > 50000
        
        if !isPseudoword && userKnows {
            // Correctly identified real word
            correctCount += 1
        } else if isPseudoword && userKnows {
            // False alarm - claimed to know fake word
            correctCount -= 2  // Penalty for overconfidence
        } else if !isPseudoword && !userKnows {
            // Correctly identified as unknown (or actually doesn't know)
            // No penalty
        }
        
        currentIndex += 1
        updateEstimatedLevel()
    }
    
    /// Update estimated CEFR level based on performance
    private func updateEstimatedLevel() {
        guard currentIndex > 0 else { return }
        
        let accuracy = Double(correctCount) / Double(currentIndex)
        
        // Adaptive level estimation
        if accuracy >= 0.85 {
            currentEstimatedLevel = .C1
        } else if accuracy >= 0.75 {
            currentEstimatedLevel = .B2
        } else if accuracy >= 0.65 {
            currentEstimatedLevel = .B1
        } else if accuracy >= 0.50 {
            currentEstimatedLevel = .A2
        } else {
            currentEstimatedLevel = .A1
        }
    }
    
    // MARK: - Results
    
    /// Get current test progress
    func getProgress() -> (current: Int, total: Int) {
        return (currentIndex, testWords.count)
    }
    
    /// Get current test word
    func getCurrentWord() -> TestWord? {
        guard currentIndex < testWords.count else { return nil }
        return testWords[currentIndex]
    }
    
    /// Check if test is complete
    func isComplete() -> Bool {
        return currentIndex >= testWords.count
    }
    
    /// Get final assessment results
    func getFinalResults() -> AssessmentResults {
        let realWords = testWords.filter { $0.frequencyRank < 50000 }
        let knownWords = realWords.prefix(correctCount > 0 ? correctCount : 0)
        let estimatedVocabSize = calculateEstimatedVocabSize()
        
        return AssessmentResults(
            cefrLevel: currentEstimatedLevel,
            accuracy: Double(correctCount) / Double(testWords.count),
            knownWordsCount: max(0, correctCount),
            estimatedVocabSize: estimatedVocabSize,
            recommendedStartingPoint: getRecommendedStartingPoint()
        )
    }
    
    /// Calculate estimated total vocabulary size
    private func calculateEstimatedVocabSize() -> Int {
        // Estimate based on CEFR level
        switch currentEstimatedLevel {
        case .A1: return 500
        case .A2: return 1000
        case .B1: return 2000
        case .B2: return 3500
        case .C1: return 5000
        case .C2: return 7000
        }
    }
    
    /// Get recommended starting frequency rank
    private func getRecommendedStartingPoint() -> Int {
        return currentEstimatedLevel.maxFrequency
    }
    
    // MARK: - Curriculum Generation
    
    /// Generate initial curriculum based on assessment
    func getInitialCurriculum() -> [VocabularyCard] {
        let maxFrequency = currentEstimatedLevel.maxFrequency
        return loadVocabularyUpToFrequency(maxFrequency)
    }
    
    /// Load vocabulary cards up to frequency threshold
    private func loadVocabularyUpToFrequency(_ maxFreq: Int) -> [VocabularyCard] {
        let request: NSFetchRequest<VocabularyCard> = VocabularyCard.fetchRequest()
        request.predicate = NSPredicate(format: "frequencyRank <= %d", maxFreq)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isCognate", ascending: false),
            NSSortDescriptor(key: "frequencyRank", ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error loading curriculum: \(error)")
            return []
        }
    }
    
    /// Create user profile from assessment
    func createUserProfile() -> UserProfile {
        let profile = UserProfile(context: context)
        profile.cefrLevelEnum = currentEstimatedLevel
        profile.vocabularySize = Int32(calculateEstimatedVocabSize())
        profile.estimatedLevel = getLevelDescription()
        
        // Set reasonable defaults based on level
        profile.dailyNewCardGoal = currentEstimatedLevel == .A1 ? 15 : 10
        profile.maxDailyReviews = currentEstimatedLevel == .A1 ? 50 : 100
        
        return profile
    }
    
    /// Get human-readable level description
    private func getLevelDescription() -> String {
        switch currentEstimatedLevel {
        case .A1: return "Beginner"
        case .A2: return "Elementary"
        case .B1: return "Intermediate"
        case .B2: return "Upper Intermediate"
        case .C1: return "Advanced"
        case .C2: return "Proficient"
        }
    }
}

// MARK: - Supporting Types

struct TestWord {
    let dutch: String
    let english: String
    let cefrLevel: CEFRLevel
    let frequencyRank: Int
    let isCognate: Bool
}

struct AssessmentResults {
    let cefrLevel: CEFRLevel
    let accuracy: Double
    let knownWordsCount: Int
    let estimatedVocabSize: Int
    let recommendedStartingPoint: Int
}
