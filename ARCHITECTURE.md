# Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        iOS APP: DutchLearning                        │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER (SwiftUI)                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ OnboardingView│  │ ReviewCardView│  │ DashboardView│              │
│  │              │  │              │  │              │              │
│  │ - Welcome    │  │ - Card Display│ │ - Stats      │              │
│  │ - Assessment │  │ - Flip        │ │ - Streaks    │              │
│  │ - Setup      │  │ - Rating      │ │ - Progress   │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                  │                  │                      │
└─────────┼──────────────────┼──────────────────┼──────────────────────┘
          │                  │                  │
┌─────────┼──────────────────┼──────────────────┼──────────────────────┐
│         │     BUSINESS LOGIC LAYER (ViewModels & Services)           │
├─────────┼──────────────────┼──────────────────┼──────────────────────┤
│         ▼                  ▼                  ▼                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ Assessment   │  │ Review       │  │ Dashboard    │              │
│  │ ViewModel    │  │ ViewModel    │  │ ViewModel    │              │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘              │
│         │                  │                                         │
│  ┌──────▼──────────────────▼──────────────────────────────────┐    │
│  │              SESSION MANAGER (Core Orchestrator)            │    │
│  │  • generateDailySession()   • processReview()               │    │
│  │  • fetchDueCards()          • updateStreak()                │    │
│  │  • interleaveCards()        • calculateRetention()          │    │
│  └──────┬──────────────────┬─────────────┬─────────────────────┘    │
│         │                  │             │                          │
│  ┌──────▼───────┐  ┌───────▼──────┐  ┌──▼──────────────────────┐   │
│  │  FSRS 4.5    │  │  Proficiency │  │  AI Personalization     │   │
│  │  Scheduler   │  │  Assessment  │  │  Engine                 │   │
│  │              │  │              │  │                         │   │
│  │ • schedule() │  │ • evaluate() │  │ • generateExample()     │   │
│  │ • calcR()    │  │ • testWords  │  │ • generateMnemonic()    │   │
│  │ • calcD()    │  │ • results()  │  │ • explainError()        │   │
│  │ • calcS()    │  │              │  │ • detectGaps()          │   │
│  └──────────────┘  └──────────────┘  └─────────┬───────────────┘   │
│                                                 │                   │
└─────────────────────────────────────────────────┼───────────────────┘
                                                  │
                                       ┌──────────▼──────────┐
                                       │   OpenAI GPT-4 API  │
                                       │   (External Service)│
                                       └─────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        DATA LAYER (Core Data)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                  CORE DATA PERSISTENT STORE                  │    │
│  │                                                               │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │    │
│  │  │ Vocabulary   │  │ Example      │  │ Review       │      │    │
│  │  │ Card         │──│ Sentence     │  │ Record       │      │    │
│  │  │              │  │              │  │              │      │    │
│  │  │ • FSRS params│  │ • dutch      │  │ • timestamp  │      │    │
│  │  │ • word data  │  │ • english    │  │ • rating     │      │    │
│  │  │ • nextReview │  │ • aiGenerate │  │ • respTime   │      │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │    │
│  │                                                               │    │
│  │  ┌──────────────┐  ┌──────────────┐                         │    │
│  │  │ User         │  │ Session      │                         │    │
│  │  │ Profile      │  │              │                         │    │
│  │  │              │  │ • stats      │                         │    │
│  │  │ • CEFR level │  │ • duration   │                         │    │
│  │  │ • preferences│  │ • ratings    │                         │    │
│  │  │ • gamification│  │              │                         │    │
│  │  └──────────────┘  └──────────────┘                         │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                       EXTERNAL DATA SOURCES                          │
├─────────────────────────────────────────────────────────────────────┤
│  • Dutch frequency lists (OpenSubtitles corpus)                      │
│  • CEFR vocabulary databases                                         │
│  • NT2 (Nederlands als Tweede Taal) word lists                      │
│  • CloudKit (optional sync)                                          │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow Examples

### 1. Daily Review Session Flow
```
User opens app
    ↓
SessionManager.generateDailySession()
    ↓
Fetch due cards from Core Data (nextReview <= today)
    ↓
Sort by priority (overdue first, then retrievability)
    ↓
Add new cards (cognates first, high frequency)
    ↓
Interleave 3:1 ratio (review:new)
    ↓
Return card list to ReviewViewModel
    ↓
Display first card in ReviewCardView
    ↓
User rates card (Again/Hard/Good/Easy)
    ↓
SessionManager.processReview()
    ↓
FSRSScheduler.schedule() → new D, S, interval
    ↓
Update card in Core Data
    ↓
Create ReviewRecord
    ↓
Update UserProfile stats
    ↓
Next card or session complete
```

### 2. AI Example Generation Flow
```
User struggles with card (rated "Again")
    ↓
SessionManager detects repeated failure
    ↓
Triggers AIPersonalizationEngine.generatePersonalizedExample()
    ↓
Fetch user's known vocabulary from Core Data
    ↓
Build prompt with constraints (interests, CEFR, known words)
    ↓
Call OpenAI GPT-4 API
    ↓
Parse JSON response
    ↓
Create ExampleSentence entity (aiGenerated = true)
    ↓
Save to Core Data linked to card
    ↓
Display in ReviewCardView on next review
```

### 3. FSRS Scheduling Algorithm
```
User rates card
    ↓
FSRSScheduler.schedule(card, rating)
    ↓
1. Calculate current retrievability
   R = (1 + daysSince / (9*S))^(-0.5)
    ↓
2. Update difficulty
   D' = D + delta[rating]  (clamp 1-10)
    ↓
3. Calculate new stability
   If new card: S' = w[0-3] based on rating
   If review: S' = S * exponential formula
    ↓
4. Calculate interval
   I = S' * (R^(1/decay) - 1)
    ↓
5. Determine new state
   new → learning → review → relearning
    ↓
Return (interval, D', S', R', state')
    ↓
SessionManager updates card
    ↓
nextReview = today + interval days
```

## Component Dependencies

```
ReviewCardView
    ↓
ReviewViewModel
    ↓
SessionManager ───┬──→ FSRSScheduler
                  ├──→ AIPersonalizationEngine → OpenAI API
                  └──→ Core Data

ProficiencyAssessment
    ↓
Core Data (VocabularyCard)
    ↓
Creates UserProfile with estimated level
```

## File Organization

```
Core/Models/CoreDataModels.swift
    • All enums (CardState, CEFRLevel, WordType, Gender, Rating, etc.)
    • VocabularyCard entity
    • ExampleSentence entity
    • ReviewRecord entity
    • UserProfile entity
    • Session entity

Core/Scheduling/FSRSScheduler.swift
    • 19-parameter algorithm
    • Retrievability calculation
    • Difficulty/Stability updates
    • Interval calculation
    • ScheduleResult type

Core/AI/AIPersonalizationEngine.swift
    • OpenAI API client
    • Example generation
    • Mnemonic creation
    • Error explanations
    • Knowledge gap detection

Core/Services/SessionManager.swift
    • Daily session generation
    • Card fetching & sorting
    • Review processing
    • Analytics & streaks
    • Core Data transactions

Core/Services/ProficiencyAssessment.swift
    • 35-word test + 4 pseudowords
    • Adaptive level estimation
    • Curriculum generation
    • UserProfile creation

Features/Review/ReviewCardView.swift
    • Main review UI (SwiftUI)
    • Card display component
    • Rating buttons
    • ReviewViewModel (MVVM)
```

## Key Algorithms Implemented

### FSRS 4.5 (Fully Implemented)
- **Retrievability:** `R = (1 + t/(9*S))^decay`
- **Difficulty:** `D' = clamp(D + delta, 1, 10)`
- **Stability (new):** `S' = w[rating]`
- **Stability (review):** `S' = S * (1 + exp(w[8]) * (11-D) * S^w[9] * ...)`
- **Interval:** `I = S * (R^(1/decay) - 1)`

### Adaptive Assessment
- **Accuracy threshold:** >85% = C1, >75% = B2, >65% = B1, >50% = A2, else A1
- **False alarm penalty:** -2 points for claiming fake words
- **Vocabulary estimation:** Level-based lookup table

### Session Optimization
- **Priority sorting:** Overdue → Low retrievability → New cards
- **Interleaving:** 3 review cards per 1 new card
- **Backlog prevention:** Cap at `maxDailyReviews`
- **Cognate prioritization:** Easy wins first for motivation
