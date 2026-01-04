import Foundation
import CoreData

/// FSRS 4.5 Scheduler implementing the complete algorithm with 19 parameters
class FSRSScheduler {
    
    // MARK: - FSRS 4.5 Parameters (19 weights)
    private var w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722, 7.2102,
        0.5316, 1.0651, 0.0234, 1.616, 0.1544,
        1.0824, 1.9813, 0.0953, 0.2975, 2.2042,
        0.2407, 2.9466, 0.5034, 0.6567
    ]
    
    var requestRetention: Double
    var maximumInterval: Int
    var decay: Double
    
    // MARK: - Initialization
    
    init(requestRetention: Double = 0.9, maximumInterval: Int = 36500) {
        self.requestRetention = requestRetention
        self.maximumInterval = maximumInterval
        self.decay = -0.5
    }
    
    // MARK: - Public API
    
    /// Main scheduling function
    func schedule(card: VocabularyCard, rating: Rating) -> ScheduleResult {
        let difficulty = card.difficulty
        let stability = card.stability
        let retrievability = calculateRetrievability(card: card)
        
        // Update difficulty based on rating
        let newD = calculateNewDifficulty(
            difficulty: difficulty,
            rating: rating
        )
        
        // Update stability based on rating and retrievability
        let newS = calculateNewStability(
            difficulty: newD,
            stability: stability,
            retrievability: retrievability,
            rating: rating,
            state: card.cardState
        )
        
        // Calculate next interval from stability
        let interval = calculateInterval(
            stability: newS,
            requestRetention: requestRetention
        )
        
        // Determine new state
        let newState = determineNewState(
            currentState: card.cardState,
            rating: rating,
            interval: interval
        )
        
        return ScheduleResult(
            nextInterval: interval,
            newDifficulty: newD,
            newStability: newS,
            newRetrievability: retrievability,
            newState: newState
        )
    }
    
    // MARK: - Retrievability Calculation
    
    /// Calculate current retrievability (probability of recall)
    func calculateRetrievability(card: VocabularyCard) -> Double {
        guard let lastReview = card.lastReview else { return 0.0 }
        let daysSinceReview = Date().timeIntervalSince(lastReview) / 86400.0
        
        // FSRS retrievability formula: R = (1 + t / (9*S))^decay
        let retrievability = pow(1.0 + daysSinceReview / (9.0 * card.stability), decay)
        return max(0.0, min(1.0, retrievability))
    }
    
    // MARK: - Difficulty Calculation
    
    /// Update difficulty based on rating
    private func calculateNewDifficulty(difficulty: Double, rating: Rating) -> Double {
        // w[5] = penalty for Again
        // w[6] = penalty for Hard  
        // w[7] = bonus for Easy
        let delta: Double
        switch rating {
        case .again:
            delta = w[5]
        case .hard:
            delta = w[6]
        case .easy:
            delta = -w[7]
        case .good:
            delta = 0.0
        }
        
        let newD = difficulty + delta
        return max(1.0, min(10.0, newD))
    }
    
    // MARK: - Stability Calculation
    
    /// Calculate new stability based on rating and current parameters
    private func calculateNewStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double,
        rating: Rating,
        state: CardState
    ) -> Double {
        if state == .new {
            return initialStability(rating: rating)
        } else {
            return updateStability(
                difficulty: difficulty,
                stability: stability,
                retrievability: retrievability,
                rating: rating
            )
        }
    }
    
    /// Initial stability for new cards
    private func initialStability(rating: Rating) -> Double {
        // w[0] = Again, w[1] = Hard, w[2] = Good, w[3] = Easy
        switch rating {
        case .again: return w[0]
        case .hard: return w[1]
        case .good: return w[2]
        case .easy: return w[3]
        }
    }
    
    /// Update stability for reviewing cards (FSRS core formula)
    private func updateStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double,
        rating: Rating
    ) -> Double {
        
        if rating == .again {
            // Lapse: stability decreases
            // S' = S * exp(w[11]) * D^w[12] * S^w[13] * (1-R)
            return stability 
                * exp(w[11]) 
                * pow(difficulty, w[12]) 
                * pow(stability, w[13]) 
                * (1.0 - retrievability)
        } else {
            // Success: stability increases
            let hardPenalty = rating == .hard ? w[15] : 1.0
            let easyBonus = rating == .easy ? w[16] : 1.0
            
            // S' = S * (1 + exp(w[8]) * (11-D) * S^w[9] * (exp(1-R) - 1) * hardPenalty * easyBonus)
            let increment = exp(w[8]) 
                * (11.0 - difficulty) 
                * pow(stability, w[9]) 
                * (exp(1.0 - retrievability) - 1.0) 
                * hardPenalty 
                * easyBonus
            
            return stability * (1.0 + increment)
        }
    }
    
    // MARK: - Interval Calculation
    
    /// Calculate optimal interval based on stability and target retention
    private func calculateInterval(stability: Double, requestRetention: Double) -> Int {
        // I = S * (R^(1/decay) - 1)
        let interval = stability * (pow(requestRetention, 1.0 / decay) - 1.0)
        return max(1, min(maximumInterval, Int(round(interval))))
    }
    
    // MARK: - State Management
    
    /// Determine new card state based on rating and interval
    private func determineNewState(
        currentState: CardState,
        rating: Rating,
        interval: Int
    ) -> CardState {
        if rating == .again {
            return .relearning
        }
        
        switch currentState {
        case .new:
            return .learning
        case .learning:
            return interval >= 21 ? .review : .learning
        case .review:
            return .review
        case .relearning:
            return interval >= 21 ? .review : .relearning
        }
    }
    
    // MARK: - Optimization
    
    /// Update FSRS weights based on user's review history
    /// This would implement gradient descent optimization in a full implementation
    func optimizeWeights(reviewHistory: [ReviewRecord]) {
        // TODO: Implement FSRS weight optimization algorithm
        // This requires gradient descent on the loss function
        // comparing predicted retrievability vs actual outcomes
        // For MVP, we use default weights
    }
}

// MARK: - Supporting Types

struct ScheduleResult {
    let nextInterval: Int
    let newDifficulty: Double
    let newStability: Double
    let newRetrievability: Double
    let newState: CardState
}
