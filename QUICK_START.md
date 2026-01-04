# Quick Start Guide

## Getting Started in 10 Minutes

### Step 1: Create Xcode Project (2 min)
```bash
1. Open Xcode
2. File > New > Project
3. Choose "iOS" > "App"
4. Name: DutchLearning
5. Interface: SwiftUI
6. Storage: Core Data ✓
7. Create
```

### Step 2: Add Files to Project (3 min)
```bash
1. In Finder, navigate to: dutchidigo/DutchLearning/
2. Drag the entire "Core" folder into Xcode project navigator
3. Drag the entire "Features" folder into Xcode
4. ✓ "Copy items if needed"
5. ✓ "Create groups"
6. Add to target: DutchLearning
```

### Step 3: Create Core Data Model (5 min)
```bash
1. In Xcode, find "DutchLearning.xcdatamodeld"
2. Click to open Core Data editor
3. Add Entity: "VocabularyCard"
4. Add attributes (see README.md for full list):
   - id: UUID
   - dutchWord: String
   - englishTranslation: String
   - difficulty: Double (default: 5.0)
   - stability: Double (default: 1.0)
   - nextReview: Date
   - state: String
   ... (30+ more - see README)

5. Add Entity: "ExampleSentence" (with relationship to VocabularyCard)
6. Add Entity: "ReviewRecord" (with relationship to VocabularyCard)
7. Add Entity: "UserProfile"
8. Add Entity: "Session"
```

**Shortcut:** See `README.md` section "2. Add Core Data Model" for complete attribute list.

### Step 4: Build and Verify
```bash
1. Press Cmd+B to build
2. Compilation errors are expected (Core Data entities need generation)
3. Xcode > Editor > Create NSManagedObject Subclass
4. Select all 5 entities
5. Replace generated files with our custom ones
6. Build again - should succeed!
```

## What You Have Now

✅ Complete FSRS 4.5 scheduling algorithm
✅ AI personalization engine (needs API key)
✅ Session management system
✅ Proficiency assessment
✅ Review UI with animations

## What You Need Next

### To See It Run (15 min)
1. Create a simple App.swift entry point
2. Add a few test vocabulary cards to Core Data
3. Initialize SessionManager
4. Present ReviewCardView
5. Run on simulator

### To Make It Real (2 weeks)
1. Import 1000+ Dutch words with frequency/CEFR data
2. Add OpenAI API key for AI features
3. Build onboarding flow
4. Create dashboard
5. Test with real learners

## Project Structure At A Glance

```
DutchLearning/
├── Core/
│   ├── Models/CoreDataModels.swift          # 5 entities, all enums
│   ├── Scheduling/FSRSScheduler.swift       # FSRS 4.5 algorithm
│   ├── AI/AIPersonalizationEngine.swift     # OpenAI integration
│   └── Services/
│       ├── SessionManager.swift             # Daily review logic
│       └── ProficiencyAssessment.swift      # Placement test
├── Features/
│   └── Review/ReviewCardView.swift          # Main UI
├── README.md                                # Complete guide
└── PROJECT_SUMMARY.md                       # What's been built
```

## Key Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| CoreDataModels.swift | 418 | All data structures |
| FSRSScheduler.swift | 226 | Spaced repetition math |
| AIPersonalizationEngine.swift | 265 | GPT-4 integration |
| SessionManager.swift | 318 | Review orchestration |
| ProficiencyAssessment.swift | 239 | Placement test |
| ReviewCardView.swift | 236 | SwiftUI interface |

**Total: 1,640+ lines of production code**

## Common First Issues

### ❌ "Cannot find type 'VocabularyCard'"
**Fix:** Make sure all files are added to the same target in Xcode.

### ❌ "Entity 'VocabularyCard' not found"
**Fix:** Core Data model must match Swift classes exactly. Use Xcode's visual editor.

### ❌ Core Data relationship errors
**Fix:** Set inverse relationships in .xcdatamodeld:
- VocabularyCard.exampleSentences ↔ ExampleSentence.card
- VocabularyCard.reviewHistory ↔ ReviewRecord.card

### ❌ "No cards in session"
**Fix:** You need to manually insert test VocabularyCard objects into Core Data first.

## Testing Checklist (Once Running)

- [ ] Create a test card with `state = "new"`
- [ ] Generate session (should return 1 card)
- [ ] Display card in ReviewCardView
- [ ] Rate card as "Good"
- [ ] Verify FSRS updates: difficulty, stability, nextReview
- [ ] Check ReviewRecord was created
- [ ] Verify session stats updated

## Next Steps

1. **Read README.md** - Complete setup instructions
2. **Read PROJECT_SUMMARY.md** - Understand what's been built
3. **Follow Week 1-2 tasks** - Get it running
4. **Join community** - Share progress!

---

**Time to working prototype:** ~3-4 hours (with test data)
**Time to MVP:** ~6-8 weeks (with real vocabulary database and UI polish)
**Time to App Store:** ~11-16 weeks (as per original plan)

Good luck! 🚀
