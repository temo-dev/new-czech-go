package processing

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func newID() string {
	b := make([]byte, 12)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

const (
	PisemnaPassScore = 42 // 60% of 70
	UstniPassScore   = 24 // 60% of 40
	PisemnaMaxPoints = 70 // cteni=25 + psani=20 + poslech=25
	UstniMaxPoints   = 40
)

// IsPisemnaPassed returns true when písemná score meets the 60% threshold.
func IsPisemnaPassed(score int) bool { return score >= PisemnaPassScore }

// IsUstniPassed returns true when ústní score meets the 60% threshold.
func IsUstniPassed(score int) bool { return score >= UstniPassScore }

// IsFullExamPassed returns true only when both parts pass.
func IsFullExamPassed(pisemnaPassed, ustniPassed bool) bool {
	return pisemnaPassed && ustniPassed
}

// SumPisemnaScores adds scores from multiple písemná sections.
func SumPisemnaScores(scores []int) int {
	total := 0
	for _, s := range scores {
		total += s
	}
	return total
}

// ScoreFromAttemptFeedback extracts the numeric score from an attempt's feedback.
// For objective attempts: uses ObjectiveResult.Score.
// For writing attempts:   maps readiness_level to a fraction of maxPoints.
func ScoreFromAttemptFeedback(feedback *contracts.AttemptFeedback, maxPoints int) int {
	if feedback == nil {
		return 0
	}
	if feedback.ObjectiveResult != nil {
		return feedback.ObjectiveResult.Score
	}
	// Writing: map readiness → fraction × maxPoints
	fraction := map[string]float64{
		"strong": 1.0,
		"ok":     0.5,
		"weak":   0.0,
	}[feedback.ReadinessLevel]
	return int(fraction * float64(maxPoints))
}

// fullExamRepository is the minimal store interface needed by the full exam scorer.
type fullExamRepository interface {
	Attempt(id string) (*contracts.Attempt, bool)
	MockExamByID(id string) (contracts.MockExamSession, bool)
	SetFullExamSession(session contracts.FullExamSession)
	FullExamSession(id string) (*contracts.FullExamSession, bool)
	ListFullExamSessions(learnerID string) []contracts.FullExamSession
}

// FullExamScorer handles creation and completion of full exam sessions.
type FullExamScorer struct {
	repo fullExamRepository
}

func NewFullExamScorer(repo fullExamRepository) *FullExamScorer {
	return &FullExamScorer{repo: repo}
}

// CreateSession initialises a FullExamSession and computes the písemná score
// from the provided attempt IDs.
func (s *FullExamScorer) CreateSession(learnerID, mockTestID string, pisemnaAttemptIDs []string, pisemnaSectionMaxPoints []int) (contracts.FullExamSession, error) {
	if len(pisemnaAttemptIDs) != len(pisemnaSectionMaxPoints) {
		return contracts.FullExamSession{}, fmt.Errorf("attempt IDs and max points must have the same length")
	}

	var scores []int
	for i, attemptID := range pisemnaAttemptIDs {
		attempt, ok := s.repo.Attempt(attemptID)
		if !ok {
			return contracts.FullExamSession{}, fmt.Errorf("attempt %s not found", attemptID)
		}
		score := ScoreFromAttemptFeedback(attempt.Feedback, pisemnaSectionMaxPoints[i])
		scores = append(scores, score)
	}

	pisemnaScore := SumPisemnaScores(scores)
	pisemnaPassed := IsPisemnaPassed(pisemnaScore)

	session := contracts.FullExamSession{
		ID:            newID(),
		LearnerID:     learnerID,
		MockTestID:    mockTestID,
		PisemnaScore:  pisemnaScore,
		PisemnaPassed: pisemnaPassed,
		Status:        "pisemna_done",
		CreatedAt:     time.Now().UTC().Format(time.RFC3339),
	}
	s.repo.SetFullExamSession(session)
	return session, nil
}

// CompleteSession links the ústní mock exam session and computes overall_passed.
func (s *FullExamScorer) CompleteSession(sessionID, ustniMockExamSessionID string) (contracts.FullExamSession, error) {
	session, ok := s.repo.FullExamSession(sessionID)
	if !ok {
		return contracts.FullExamSession{}, fmt.Errorf("full exam session %s not found", sessionID)
	}

	mockExam, ok := s.repo.MockExamByID(ustniMockExamSessionID)
	if !ok {
		return contracts.FullExamSession{}, fmt.Errorf("ustni mock exam session %s not found", ustniMockExamSessionID)
	}

	ustniScore := mockExam.OverallScore
	ustniPassed := IsUstniPassed(ustniScore)

	session.UstniScore = ustniScore
	session.UstniPassed = ustniPassed
	session.OverallPassed = IsFullExamPassed(session.PisemnaPassed, ustniPassed)
	session.UstniMockExamSessionID = ustniMockExamSessionID
	session.Status = "completed"
	s.repo.SetFullExamSession(*session)
	return *session, nil
}

// findOpenFullExamForAutoLink returns the first FullExamSession that is ready
// to receive an ústní link: status is 'pisemna_done' or 'in_progress' and
// no ústní mock exam session has been linked yet.
// Returns nil if no eligible session exists.
func FindOpenFullExamForAutoLink(sessions []contracts.FullExamSession) *contracts.FullExamSession {
	for i := range sessions {
		s := &sessions[i]
		if s.UstniMockExamSessionID != "" {
			continue // already linked
		}
		if s.Status == "pisemna_done" || s.Status == "in_progress" {
			return s
		}
	}
	return nil
}
