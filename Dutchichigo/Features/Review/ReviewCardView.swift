import SwiftUI

/// Main review card view
struct ReviewCardView: View {
    @StateObject private var viewModel: ReviewViewModel
    @State private var showingAnswer = false
    @State private var responseStartTime: Date?
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress bar
            ProgressView(value: Double(viewModel.currentIndex), 
                        total: Double(viewModel.totalCards))
                .padding()
            
            Text("\(viewModel.currentIndex + 1) / \(viewModel.totalCards)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Card content
            if let card = viewModel.currentCard {
                CardContentView(card: card, showingAnswer: $showingAnswer)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
            
            Spacer()
            
            // Action buttons
            if showingAnswer {
                RatingButtonsView(onRating: { rating in
                    handleRating(rating)
                })
            } else {
                Button("Show Answer") {
                    withAnimation {
                        showingAnswer = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .onAppear {
            responseStartTime = Date()
        }
    }
    
    private func handleRating(_ rating: Rating) {
        guard let startTime = responseStartTime else { return }
        let responseTime = Date().timeIntervalSince(startTime)
        
        viewModel.submitReview(rating: rating, responseTime: responseTime)
        
        withAnimation {
            showingAnswer = false
            responseStartTime = Date()
        }
    }
}

// MARK: - Card Content

struct CardContentView: View {
    let card: VocabularyCard
    @Binding var showingAnswer: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Dutch word (always visible)
            Text(card.dutchWord)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
            
            // Example sentence (if available)
            if let example = card.exampleSentencesArray.first {
                Text(example.dutch)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            // Answer (conditional)
            if showingAnswer {
                Divider()
                    .padding(.vertical)
                
                Text(card.englishTranslation)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.blue)
                
                if let example = card.exampleSentencesArray.first {
                    Text(example.english)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Mnemonic hint (if available)
                if let mnemonic = card.mnemonicHint {
                    Text(mnemonic)
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
    }
}

// MARK: - Rating Buttons

struct RatingButtonsView: View {
    let onRating: (Rating) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                RatingButton(title: "Again", 
                           subtitle: "< 1 min",
                           color: .red,
                           rating: .again,
                           onTap: onRating)
                
                RatingButton(title: "Hard",
                           subtitle: "< 10 min",
                           color: .orange,
                           rating: .hard,
                           onTap: onRating)
            }
            
            HStack(spacing: 16) {
                RatingButton(title: "Good",
                           subtitle: "4 days",
                           color: .green,
                           rating: .good,
                           onTap: onRating)
                
                RatingButton(title: "Easy",
                           subtitle: "10 days",
                           color: .blue,
                           rating: .easy,
                           onTap: onRating)
            }
        }
        .padding()
    }
}

struct RatingButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let rating: Rating
    let onTap: (Rating) -> Void
    
    var body: some View {
        Button {
            onTap(rating)
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.2))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model

@MainActor
class ReviewViewModel: ObservableObject {
    @Published var cards: [VocabularyCard] = []
    @Published var currentIndex = 0
    @Published var isComplete = false
    
    private let sessionManager: SessionManager
    private let userProfile: UserProfile
    
    var currentCard: VocabularyCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }
    
    var totalCards: Int {
        cards.count
    }
    
    init(sessionManager: SessionManager, userProfile: UserProfile) {
        self.sessionManager = sessionManager
        self.userProfile = userProfile
        loadSession()
    }
    
    func loadSession() {
        cards = sessionManager.generateDailySession(userProfile: userProfile)
    }
    
    func submitReview(rating: Rating, responseTime: TimeInterval) {
        guard let card = currentCard else { return }
        
        sessionManager.processReview(
            card: card,
            rating: rating,
            responseTime: responseTime,
            userProfile: userProfile
        )
        
        currentIndex += 1
        
        if currentIndex >= cards.count {
            isComplete = true
            sessionManager.endSession()
        }
    }
}
