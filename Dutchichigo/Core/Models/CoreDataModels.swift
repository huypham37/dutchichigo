import Foundation
import CoreData

// MARK: - Enums

enum CardState: String, CaseIterable {
    case new
    case learning
    case review
    case relearning
}

enum CEFRLevel: String, CaseIterable {
    case A1, A2, B1, B2, C1, C2
    
    var maxFrequency: Int {
        switch self {
        case .A1: return 500
        case .A2: return 1500
        case .B1: return 3500
        case .B2: return 5000
        case .C1: return 7000
        case .C2: return 10000
        }
    }
}

enum WordType: String, CaseIterable {
    case noun
    case verb
    case adjective
    case adverb
    case preposition
    case conjunction
    case pronoun
    case other
}

enum Gender: String, CaseIterable {
    case de
    case het
}

enum Rating: Int, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

enum LearningStyle: String, CaseIterable {
    case visual
    case auditory
    case reading
    case kinesthetic
    case mixed
}

enum KnowledgeGap: String {
    case verbConjugation
    case articleGender
    case wordOrder
    case falseFriends
    case separableVerbs
}

// MARK: - VocabularyCard

@objc(VocabularyCard)
public class VocabularyCard: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var dutchWord: String
    @NSManaged public var englishTranslation: String
    @NSManaged public var wordType: String
    @NSManaged public var gender: String?
    @NSManaged public var frequencyRank: Int32
    @NSManaged public var cefrLevel: String
    @NSManaged public var isCognate: Bool
    @NSManaged public var isFalseFriend: Bool
    
    // FSRS Parameters
    @NSManaged public var difficulty: Double
    @NSManaged public var stability: Double
    @NSManaged public var retrievability: Double
    @NSManaged public var lastReview: Date?
    @NSManaged public var nextReview: Date
    @NSManaged public var reviewCount: Int32
    @NSManaged public var lapseCount: Int32
    @NSManaged public var ease: Double
    
    // Learning State
    @NSManaged public var state: String
    @NSManaged public var interval: Int32
    
    // AI-Generated Content
    @NSManaged public var personalizedContext: String?
    @NSManaged public var mnemonicHint: String?
    
    // Relationships
    @NSManaged public var exampleSentences: NSSet?
    @NSManaged public var reviewHistory: NSSet?
}

// MARK: - VocabularyCard Extensions

extension VocabularyCard {
    @objc(addExampleSentencesObject:)
    @NSManaged public func addToExampleSentences(_ value: ExampleSentence)
    
    @objc(removeExampleSentencesObject:)
    @NSManaged public func removeFromExampleSentences(_ value: ExampleSentence)
    
    @objc(addExampleSentences:)
    @NSManaged public func addToExampleSentences(_ values: NSSet)
    
    @objc(removeExampleSentences:)
    @NSManaged public func removeFromExampleSentences(_ values: NSSet)
    
    @objc(addReviewHistoryObject:)
    @NSManaged public func addToReviewHistory(_ value: ReviewRecord)
    
    @objc(removeReviewHistoryObject:)
    @NSManaged public func removeFromReviewHistory(_ value: ReviewRecord)
    
    @objc(addReviewHistory:)
    @NSManaged public func addToReviewHistory(_ values: NSSet)
    
    @objc(removeReviewHistory:)
    @NSManaged public func removeFromReviewHistory(_ values: NSSet)
}

extension VocabularyCard {
    var cardState: CardState {
        get { CardState(rawValue: state) ?? .new }
        set { state = newValue.rawValue }
    }
    
    var cefrLevelEnum: CEFRLevel {
        get { CEFRLevel(rawValue: cefrLevel) ?? .A1 }
        set { cefrLevel = newValue.rawValue }
    }
    
    var wordTypeEnum: WordType {
        get { WordType(rawValue: wordType) ?? .other }
        set { wordType = newValue.rawValue }
    }
    
    var genderEnum: Gender? {
        get { 
            guard let gender = gender else { return nil }
            return Gender(rawValue: gender)
        }
        set { gender = newValue?.rawValue }
    }
    
    var exampleSentencesArray: [ExampleSentence] {
        let set = exampleSentences as? Set<ExampleSentence> ?? []
        return set.sorted { $0.difficulty < $1.difficulty }
    }
    
    var reviewHistoryArray: [ReviewRecord] {
        let set = reviewHistory as? Set<ReviewRecord> ?? []
        return set.sorted { $0.timestamp < $1.timestamp }
    }
    
    convenience init(context: NSManagedObjectContext) {
        self.init(entity: VocabularyCard.entity(), insertInto: context)
        self.id = UUID()
        self.nextReview = Date()
        self.difficulty = 5.0
        self.stability = 1.0
        self.retrievability = 0.0
        self.ease = 2.5
        self.state = CardState.new.rawValue
        self.interval = 0
        self.reviewCount = 0
        self.lapseCount = 0
    }
}

// MARK: - ExampleSentence

@objc(ExampleSentence)
public class ExampleSentence: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var dutch: String
    @NSManaged public var english: String
    @NSManaged public var difficulty: Int32
    @NSManaged public var aiGenerated: Bool
    @NSManaged public var createdAt: Date
    
    @NSManaged public var card: VocabularyCard?
    
    convenience init(context: NSManagedObjectContext, dutch: String, english: String, difficulty: Int32, aiGenerated: Bool) {
        self.init(entity: ExampleSentence.entity(), insertInto: context)
        self.id = UUID()
        self.dutch = dutch
        self.english = english
        self.difficulty = difficulty
        self.aiGenerated = aiGenerated
        self.createdAt = Date()
    }
}

// MARK: - ReviewRecord

@objc(ReviewRecord)
public class ReviewRecord: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var responseTime: Double
    @NSManaged public var rating: Int32
    @NSManaged public var wasCorrect: Bool
    
    @NSManaged public var card: VocabularyCard?
    
    convenience init(context: NSManagedObjectContext, rating: Rating, responseTime: Double, wasCorrect: Bool) {
        self.init(entity: ReviewRecord.entity(), insertInto: context)
        self.id = UUID()
        self.timestamp = Date()
        self.rating = Int32(rating.rawValue)
        self.responseTime = responseTime
        self.wasCorrect = wasCorrect
    }
}

extension ReviewRecord {
    var ratingEnum: Rating {
        get { Rating(rawValue: Int(rating)) ?? .good }
        set { rating = Int32(newValue.rawValue) }
    }
}

// MARK: - UserProfile

@objc(UserProfile)
public class UserProfile: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var createdDate: Date
    
    // Proficiency
    @NSManaged public var currentCEFRLevel: String
    @NSManaged public var vocabularySize: Int32
    @NSManaged public var estimatedLevel: String
    
    // Learning Preferences
    @NSManaged public var targetRetention: Double
    @NSManaged public var dailyNewCardGoal: Int32
    @NSManaged public var maxDailyReviews: Int32
    @NSManaged public var sessionLengthMinutes: Int32
    @NSManaged public var preferredStudyTimesData: Data?
    
    // Personalization
    @NSManaged public var interestsData: Data?
    @NSManaged public var learningStyle: String
    @NSManaged public var nativeLanguage: String
    @NSManaged public var motivation: String
    
    // Gamification
    @NSManaged public var currentStreak: Int32
    @NSManaged public var longestStreak: Int32
    @NSManaged public var totalCardsReviewed: Int32
    @NSManaged public var totalCardsLearned: Int32
    @NSManaged public var experiencePoints: Int32
    @NSManaged public var achievementsData: Data?
    
    // Analytics
    @NSManaged public var averageRetentionRate: Double
    @NSManaged public var averageResponseTime: Double
    @NSManaged public var weeklyActiveMinutes: Int32
    
    convenience init(context: NSManagedObjectContext) {
        self.init(entity: UserProfile.entity(), insertInto: context)
        self.id = UUID()
        self.createdDate = Date()
        self.currentCEFRLevel = CEFRLevel.A1.rawValue
        self.vocabularySize = 0
        self.estimatedLevel = "Beginner"
        self.targetRetention = 0.9
        self.dailyNewCardGoal = 10
        self.maxDailyReviews = 100
        self.sessionLengthMinutes = 10
        self.learningStyle = LearningStyle.mixed.rawValue
        self.nativeLanguage = "en"
        self.motivation = "personal"
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalCardsReviewed = 0
        self.totalCardsLearned = 0
        self.experiencePoints = 0
        self.averageRetentionRate = 0.0
        self.averageResponseTime = 0.0
        self.weeklyActiveMinutes = 0
    }
}

extension UserProfile {
    var cefrLevelEnum: CEFRLevel {
        get { CEFRLevel(rawValue: currentCEFRLevel) ?? .A1 }
        set { currentCEFRLevel = newValue.rawValue }
    }
    
    var learningStyleEnum: LearningStyle {
        get { LearningStyle(rawValue: learningStyle) ?? .mixed }
        set { learningStyle = newValue.rawValue }
    }
    
    var interests: [String] {
        get {
            guard let data = interestsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            interestsData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Session

@objc(Session)
public class Session: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var durationSeconds: Int32
    @NSManaged public var cardsReviewed: Int32
    @NSManaged public var newCardsIntroduced: Int32
    @NSManaged public var averageResponseTime: Double
    @NSManaged public var completionRate: Double
    @NSManaged public var cardsAgain: Int32
    @NSManaged public var cardsHard: Int32
    @NSManaged public var cardsGood: Int32
    @NSManaged public var cardsEasy: Int32
    
    convenience init(context: NSManagedObjectContext) {
        self.init(entity: Session.entity(), insertInto: context)
        self.id = UUID()
        self.date = Date()
        self.durationSeconds = 0
        self.cardsReviewed = 0
        self.newCardsIntroduced = 0
        self.averageResponseTime = 0.0
        self.completionRate = 0.0
        self.cardsAgain = 0
        self.cardsHard = 0
        self.cardsGood = 0
        self.cardsEasy = 0
    }
}
