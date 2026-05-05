package email

import (
	"context"
	"strings"
	"testing"
)

// ── Sender interface + recorder ──────────────────────────────────────────

func TestRecorderSender_RecordsAllFields(t *testing.T) {
	r := NewRecorderSender()

	err := r.Send(context.Background(), Message{
		To:        "learner@example.com",
		Subject:   "Hi",
		HTMLBody:  "<p>Hello</p>",
		TextBody:  "Hello",
		FromName:  "Czech Go",
		FromEmail: "noreply@czechgo.hadoo.eu",
	})
	if err != nil {
		t.Fatalf("send: %v", err)
	}

	got := r.Sent()
	if len(got) != 1 {
		t.Fatalf("expected 1 message recorded, got %d", len(got))
	}
	if got[0].To != "learner@example.com" {
		t.Errorf("To: %q", got[0].To)
	}
	if got[0].Subject != "Hi" {
		t.Errorf("Subject: %q", got[0].Subject)
	}
}

// ── Templates ────────────────────────────────────────────────────────────

func TestRenderVerifyEmail_IncludesLinkAndName(t *testing.T) {
	body, subject, err := RenderVerifyEmail(VerifyEmailData{
		DisplayName: "An",
		VerifyURL:   "https://czechgo.hadoo.eu/v1/auth/verify-email?token=abc",
		ExpiresHrs:  24,
	})
	if err != nil {
		t.Fatalf("render: %v", err)
	}
	mustContainBody(t, body, "An")
	mustContainBody(t, body, "https://czechgo.hadoo.eu/v1/auth/verify-email?token=abc")
	mustContainBody(t, body, "24")
	if !strings.Contains(subject, "Xác minh") {
		t.Errorf("expected VI subject, got %q", subject)
	}
}

func TestRenderVerifyEmail_EscapesHTMLInDisplayName(t *testing.T) {
	body, _, err := RenderVerifyEmail(VerifyEmailData{
		DisplayName: "<script>alert(1)</script>",
		VerifyURL:   "https://example.com",
		ExpiresHrs:  24,
	})
	if err != nil {
		t.Fatalf("render: %v", err)
	}
	if strings.Contains(body, "<script>") {
		t.Error("expected DisplayName to be HTML-escaped")
	}
	if !strings.Contains(body, "&lt;script&gt;") {
		t.Errorf("expected escaped script tag, body: %s", body)
	}
}

func TestRenderPasswordResetEmail_IncludesLinkAndExpiry(t *testing.T) {
	body, subject, err := RenderPasswordResetEmail(PasswordResetEmailData{
		DisplayName: "Bao",
		ResetURL:    "https://czechgo.hadoo.eu/reset?token=xyz",
		ExpiresMin:  60,
	})
	if err != nil {
		t.Fatalf("render: %v", err)
	}
	mustContainBody(t, body, "Bao")
	mustContainBody(t, body, "https://czechgo.hadoo.eu/reset?token=xyz")
	mustContainBody(t, body, "60")
	if !strings.Contains(subject, "Đặt lại") {
		t.Errorf("expected VI subject mentioning reset, got %q", subject)
	}
}

func TestRenderPasswordChangedEmail_IsSecurityNotice(t *testing.T) {
	body, subject, err := RenderPasswordChangedEmail(PasswordChangedEmailData{
		DisplayName: "Cuong",
		ChangedAt:   "2026-05-05 14:30 (Asia/Ho_Chi_Minh)",
	})
	if err != nil {
		t.Fatalf("render: %v", err)
	}
	mustContainBody(t, body, "Cuong")
	mustContainBody(t, body, "2026-05-05 14:30")
	if !strings.Contains(subject, "Mật khẩu") {
		t.Errorf("expected VI subject mentioning password, got %q", subject)
	}
	// Security email must tell the learner what to do if they did NOT
	// trigger the change. The plain-text "không phải bạn" / "not you"
	// guidance is the actionable part.
	if !strings.Contains(body, "không phải bạn") && !strings.Contains(body, "not you") {
		t.Errorf("expected recovery guidance in body, got: %s", body)
	}
}

func TestAllTemplates_HaveEnglishFallback(t *testing.T) {
	// Vietnamese is primary but every template ships with an English
	// fallback block so non-VI inboxes still get useful content.
	cases := []struct {
		name string
		body string
	}{
		{"verify", mustRenderVerify(t)},
		{"reset", mustRenderReset(t)},
		{"changed", mustRenderChanged(t)},
	}
	for _, c := range cases {
		hasEnglishMarker := strings.Contains(c.body, "English") ||
			strings.Contains(c.body, "Hello") ||
			strings.Contains(c.body, "Verify") ||
			strings.Contains(c.body, "Reset") ||
			strings.Contains(c.body, "password was changed")
		if !hasEnglishMarker {
			t.Errorf("%s template missing English fallback content", c.name)
		}
	}
}

func TestSenderHelpers_RenderAndSend(t *testing.T) {
	r := NewRecorderSender()

	if err := SendVerifyEmail(context.Background(), r, "learner@example.com", VerifyEmailData{
		DisplayName: "An",
		VerifyURL:   "https://example.com/verify?token=t",
		ExpiresHrs:  24,
	}); err != nil {
		t.Fatalf("send verify: %v", err)
	}

	got := r.Sent()
	if len(got) != 1 {
		t.Fatalf("expected 1 sent, got %d", len(got))
	}
	if got[0].To != "learner@example.com" {
		t.Errorf("To: %q", got[0].To)
	}
	if !strings.Contains(got[0].HTMLBody, "verify?token=t") {
		t.Error("expected rendered HTML to be in HTMLBody")
	}
	if !strings.Contains(got[0].TextBody, "verify?token=t") {
		t.Error("expected text fallback to include the verify URL")
	}
}

// ── SMTP MIME encoding ───────────────────────────────────────────────────

func TestEncodeSubject_PassesAsciiThrough(t *testing.T) {
	if got := encodeSubject("Reset your password"); got != "Reset your password" {
		t.Errorf("ASCII subject must not be encoded, got %q", got)
	}
}

func TestEncodeSubject_BasesEncodesUTF8(t *testing.T) {
	got := encodeSubject("Xác minh email")
	if !strings.HasPrefix(got, "=?UTF-8?B?") || !strings.HasSuffix(got, "?=") {
		t.Errorf("expected RFC 2047 base64 wrapper, got %q", got)
	}
}

func TestBuildMimeBody_ContainsBothParts(t *testing.T) {
	body := string(buildMimeBody(`"Czech Go" <noreply@x>`, Message{
		To:       "u@example.com",
		Subject:  "Test",
		HTMLBody: "<p>html</p>",
		TextBody: "text",
	}))
	for _, frag := range []string{
		"From: \"Czech Go\" <noreply@x>",
		"To: u@example.com",
		"Subject: Test",
		"multipart/alternative",
		"Content-Type: text/plain",
		"Content-Type: text/html",
		"text",
		"<p>html</p>",
		"--czechgo-mime-boundary--",
	} {
		if !strings.Contains(body, frag) {
			t.Errorf("MIME body missing %q\nbody:\n%s", frag, body)
		}
	}
}

func TestNewSMTPSenderFromEnv_RejectsMissingHost(t *testing.T) {
	t.Setenv("EMAIL_SMTP_HOST", "")
	if _, err := NewSMTPSenderFromEnv(); err == nil {
		t.Error("expected missing host to fail loudly")
	}
}

func TestBuildFromHeader_NameOptional(t *testing.T) {
	if got := buildFromHeader("", "noreply@x"); got != "noreply@x" {
		t.Errorf("bare email expected, got %q", got)
	}
	if got := buildFromHeader("Czech Go", "noreply@x"); !strings.HasPrefix(got, `"Czech Go"`) {
		t.Errorf("name should be quoted, got %q", got)
	}
}

// ── helpers ──────────────────────────────────────────────────────────────

func mustContainBody(t *testing.T, body, needle string) {
	t.Helper()
	if !strings.Contains(body, needle) {
		t.Errorf("body missing %q\nbody:\n%s", needle, body)
	}
}

func mustRenderVerify(t *testing.T) string {
	t.Helper()
	body, _, err := RenderVerifyEmail(VerifyEmailData{
		DisplayName: "X", VerifyURL: "https://x", ExpiresHrs: 24,
	})
	if err != nil {
		t.Fatalf("render verify: %v", err)
	}
	return body
}

func mustRenderReset(t *testing.T) string {
	t.Helper()
	body, _, err := RenderPasswordResetEmail(PasswordResetEmailData{
		DisplayName: "X", ResetURL: "https://x", ExpiresMin: 60,
	})
	if err != nil {
		t.Fatalf("render reset: %v", err)
	}
	return body
}

func mustRenderChanged(t *testing.T) string {
	t.Helper()
	body, _, err := RenderPasswordChangedEmail(PasswordChangedEmailData{
		DisplayName: "X", ChangedAt: "now",
	})
	if err != nil {
		t.Fatalf("render changed: %v", err)
	}
	return body
}
