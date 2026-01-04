import Foundation
import CoreData

/// Manages daily review sessions and card scheduling
class SessionManager {
    
    private let context: NSManagedObjectContext
    private let scheduler: FSRSScheduler
    private var currentSession: Session?
    private var sessionStartTime: Date?
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext, scheduler: FSRSScheduler) {
        self.context = context
        self.scheduler = scheduler
    }
    
    // MARK: - Session Generation
    
    /// Generate daily review session with optimal card selection
    func generateDailySession(userProfile: UserProfile) -> [VocabularyCard] {
        var sessionCards: [VocabularyCard] = []
        
        // 1. Get all cards due for review today
        let dueCards = fetchDueCards(date: Date())
        
        // 2. Sort by priority (overdue first, then by retrievability)
        let sortedDue = dueCards.sorted { card1, card2 in
            // Overdue cards first
            if card1.nextReview < card2.nextReview { return true }
            if card1.nextReview > card2.nextReview { return false }
            
            // Then by retrievability (lowest first - most at risk of forgetting)
            let r1 = scheduler.calculateRetrievability(card: card1)
            let r2 = scheduler.calculateRetrievability(card: card2)
            return r1 < r2
        }
        
        // 3. Cap at max daily reviews (prevent backlog burnout)
        let maxReviews = min(Int(userProfile.maxDailyReviews), sortedDue.count)
        sessionCards.append(contentsOf: sortedDue.prefix(maxReviews))
        
        // 4. Add new cards (if space remains)
        let remainingCapacity = Int(userProfile.maxDailyReviews) - sessionCards.count
        if remainingCapacity > 0 {
            let newCardLimit = min(Int(userProfile.dailyNewCardGoal), remainingCapacity)
            let newCards = fetchNewCards(limit: newCardLimit, userProfile: userProfile)
            sessionCards.append(contentsOf: newCards)
        }
        
        // 5. Interleave new and review cards
        let newCards = sessionCards.filter { $0.cardState == .new }
        let reviewCards = sessionCards.filter { $0.cardState != .new }
        let interleavedCards = interleaveCards(new: newCards, review: reviewCards)
        
        // 6. Start session tracking
        startSession()
        
        return interleavedCards
    }
    
    // MARK: - Card Fetching
    
    /// Fetch cards due for review
    private func fetchDueCards(date: Date) -> [VocabularyCard] {
        let request: NSFetchRequest<VocabularyCard> = VocabularyCard.fetchRequest()
        request.predicate = NSPredicate(format: "nextReview <= %@ AND state != %@", 
                                       date as CVarArg,
                                       CardState.new.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "nextReview", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching due cards: \(error)")
            return []
        }
    }
    
    /// Fetch new cards prioritized by learning efficiency
    private func fetchNewCards(limit: Int, userProfile: UserProfile) -> [VocabularyCard] {
        let request: NSFetchRequest<VocabularyCard> = VocabularyCard.fetchRequest()
        request.predicate = NSPredicate(format: "state == %@", CardState.new.rawValue)
        
        // Prioritize: cognates first, then high-frequency words
        request.sortDescriptors = [
            NSSortDescriptor(key: "isCognate", ascending: false),
            NSSortDescriptor(key: "frequencyRank", ascending: true)
        ]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching new cards: \(error)")
            return []
        }
    }
    
    /// Interleave new and review cards (3 review : 1 new ratio)
    private func interleaveCards(new: [VocabularyCard], review: [VocabularyCard]) -> [VocabularyCard] {
        var result: [VocabularyCard] = []
        var newIndex = 0
        var reviewIndex = 0
        
        while reviewIndex < review.count || newIndex < new.count {
            // Add 3 review cards
            for _ in 0..<3 {
                if reviewIndex < review.count {
                    result.append(review[reviewIndex])
                    reviewIndex += 1
                }
            }
            // Add 1 new card
            if newIndex < new.count {
                result.append(new[newIndex])
                newIndex += 1
            }
        }
        
        return result
    }
    
    // MARK: - Review Processing
    
    /// Process a review and update card parameters
    func processReview(
        card: VocabularyCard,
        rating: Rating,
        responseTime: Double,
        userProfile: UserProfile
    ) {
        // 1. Update FSRS parameters
        let result = scheduler.schedule(card: card, rating: rating)
        card.difficulty = result.newDifficulty
        card.stability = result.newStability
        card.retrievability = result.newRetrievability
        card.interval = Int32(result.nextInterval)
        card.cardState = result.newState
        
        // Calculate next review date
        let calendar = Calendar.current
        card.nextReview = calendar.date(byAdding: .day, value: result.nextInterval, to: Date()) ?? Date()
        
        // Update review stats
        card.lastReview = Date()
        card.reviewCount += 1
        
        if rating == .again {
            card.lapseCount += 1
        }
        
        // 2. Record review history
        let record = ReviewRecord(
            context: context,
            rating: rating,
            responseTime: responseTime,
            wasCorrect: rating != .again
        )
        record.card = card
        card.addToReviewHistory(record)
        
        // 3. Update user profile stats
        userProfile.totalCardsReviewed += 1
        if card.reviewCount == 1 {
            userProfile.totalCardsLearned += 1
            userProfile.vocabularySize += 1
        }
        
        // 4. Update session stats
        if let session = currentSession {
            session.cardsReviewed += 1
            
            switch rating {
            case .again: session.cardsAgain += 1
            case .hard: session.cardsHard += 1
            case .good: session.cardsGood += 1
            case .easy: session.cardsEasy += 1
            }
            
            // Update average response time
            let totalTime = session.averageResponseTime * Double(session.cardsReviewed - 1)
            session.averageResponseTime = (totalTime + responseTime) / Double(session.cardsReviewed)
        }
        
        // 5. Adaptive response time analysis
        if responseTime < 3.0 && rating == .good {
            // Fast correct answer - knowledge is strong
            // Future optimization: could slightly extend interval
        } else if responseTime > 10.0 && rating != .again {
            // Slow answer even if correct - fragile knowledge
            // Consider reducing stability slightly
            card.stability = max(1.0, card.stability * 0.95)
        }
        
        // 6. Save to Core Data
        saveContext()
    }
    
    // MARK: - Session Tracking
    
    /// Start a new review session
    private func startSession() {
        let session = Session(context: context)
        session.date = Date()
        self.currentSession = session
        self.sessionStartTime = Date()
    }
    
    /// End current session and save stats
    func endSession() {
        guard let session = currentSession,
              let startTime = sessionStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        session.durationSeconds = Int32(duration)
        
        // Calculate completion rate
        let totalCards = session.cardsReviewed
        let successfulCards = session.cardsGood + session.cardsEasy
        session.completionRate = totalCards > 0 ? Double(successfulCards) / Double(totalCards) : 0.0
        
        saveContext()
        
        currentSession = nil
        sessionStartTime = nil
    }
    
    // MARK: - Statistics
    
    /// Get today's review count
    func getTodayReviewCount() -> Int {
        let request: NSFetchRequest<ReviewRecord> = ReviewRecord.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "timestamp >= %@", startOfDay as CVarArg)
        
        do {
            return try context.count(for: request)
        } catch {
            print("Error counting reviews: \(error)")
            return 0
        }
    }
    
    /// Get count of cards due today
    func getDueCardCount() -> Int {
        return fetchDueCards(date: Date()).count
    }
    
    /// Calculate user's retention rate
    func calculateRetentionRate(userProfile: UserProfile, days: Int = 30) -> Double {
        let request: NSFetchRequest<ReviewRecord> = ReviewRecord.fetchRequest()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "timestamp >= %@", startDate as CVarArg)
        
        do {
            let records = try context.fetch(request)
            guard !records.isEmpty else { return 0.0 }
            
            let successCount = records.filter { $0.wasCorrect }.count
            return Double(successCount) / Double(records.count)
        } catch {
            print("Error calculating retention: \(error)")
            return 0.0
        }
    }
    
    /// Update streak tracking
    func updateStreak(userProfile: UserProfile) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if reviewed yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let request: NSFetchRequest<Session> = Session.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", 
                                       yesterday as CVarArg,
                                       today as CVarArg)
        
        do {
            let yesterdaySessions = try context.fetch(request)
            
            if yesterdaySessions.isEmpty {
                // Streak broken
                userProfile.currentStreak = 1
            } else {
                // Continue streak
                userProfile.currentStreak += 1
                if userProfile.currentStreak > userProfile.longestStreak {
                    userProfile.longestStreak = userProfile.currentStreak
                }
            }
            
            saveContext()
        } catch {
            print("Error updating streak: \(error)")
        }
    }
    
    // MARK: - Core Data
    
    private func saveContext() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
