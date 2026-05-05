// Package email is the V17 transactional email layer. It exposes a small
// Sender interface, three template render helpers (verify, password
// reset, password changed), and a recorder implementation for tests.
//
// The production wiring uses SMTP against AWS SES (configured via env)
// rather than the SES SDK so the only new dependency this package adds
// is on stdlib's net/smtp + crypto/tls. The Sender interface keeps the
// templates and handlers decoupled from any specific transport: a future
// migration to sesv2 SDK or a different provider only swaps the Sender.
package email

import (
	"context"
	"fmt"
	"sync"
)

// Message is the value passed to Sender.Send. It carries the rendered
// payload plus the From identity (which the SES adapter uses to set the
// `From:` header). Subject must already be rendered to plain text;
// HTMLBody and TextBody are alternatives, both should be supplied so
// clients without HTML rendering still see useful content.
type Message struct {
	To        string
	Subject   string
	HTMLBody  string
	TextBody  string
	FromName  string
	FromEmail string
}

// Sender abstracts the email transport. Implementations must NOT block
// for more than a few seconds; the auth handlers fire-and-forget any
// failure and rely on the resend-verify endpoint as the recovery path.
type Sender interface {
	Send(ctx context.Context, msg Message) error
}

// ── Recorder (test fixture) ──────────────────────────────────────────────

// RecorderSender stores every Send invocation in memory. Tests use it to
// assert that the right message was rendered and dispatched without
// hitting an SMTP server.
type RecorderSender struct {
	mu   sync.Mutex
	sent []Message
}

// NewRecorderSender returns a fresh recorder ready for use in a test.
func NewRecorderSender() *RecorderSender { return &RecorderSender{} }

// Send records the message; never returns an error.
func (r *RecorderSender) Send(_ context.Context, msg Message) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sent = append(r.sent, msg)
	return nil
}

// Sent returns a copy of every message Send received in call order.
func (r *RecorderSender) Sent() []Message {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]Message, len(r.sent))
	copy(out, r.sent)
	return out
}

// Reset drops the recorded history. Useful between sub-tests.
func (r *RecorderSender) Reset() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sent = nil
}

// ── High-level helpers ──────────────────────────────────────────────────
//
// SendVerifyEmail / SendPasswordResetEmail / SendPasswordChangedEmail
// bundle template rendering + Send so the auth handlers stay narrow.
// The From identity is read from env at call time so deploys can adjust
// the sender address without redeploying handlers.

func SendVerifyEmail(ctx context.Context, s Sender, to string, data VerifyEmailData) error {
	html, subject, err := RenderVerifyEmail(data)
	if err != nil {
		return fmt.Errorf("render verify_email: %w", err)
	}
	return s.Send(ctx, Message{
		To:        to,
		Subject:   subject,
		HTMLBody:  html,
		TextBody:  verifyEmailTextFallback(data),
		FromName:  fromName(),
		FromEmail: fromEmail(),
	})
}

func SendPasswordResetEmail(ctx context.Context, s Sender, to string, data PasswordResetEmailData) error {
	html, subject, err := RenderPasswordResetEmail(data)
	if err != nil {
		return fmt.Errorf("render password_reset: %w", err)
	}
	return s.Send(ctx, Message{
		To:        to,
		Subject:   subject,
		HTMLBody:  html,
		TextBody:  passwordResetTextFallback(data),
		FromName:  fromName(),
		FromEmail: fromEmail(),
	})
}

func SendPasswordChangedEmail(ctx context.Context, s Sender, to string, data PasswordChangedEmailData) error {
	html, subject, err := RenderPasswordChangedEmail(data)
	if err != nil {
		return fmt.Errorf("render password_changed: %w", err)
	}
	return s.Send(ctx, Message{
		To:        to,
		Subject:   subject,
		HTMLBody:  html,
		TextBody:  passwordChangedTextFallback(data),
		FromName:  fromName(),
		FromEmail: fromEmail(),
	})
}
