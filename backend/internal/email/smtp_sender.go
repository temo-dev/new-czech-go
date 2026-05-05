package email

import (
	"context"
	"crypto/tls"
	"encoding/base64"
	"errors"
	"fmt"
	"net/smtp"
	"os"
	"strconv"
	"strings"
	"time"
)

// SMTPSender sends mail through an SMTP relay (AWS SES SMTP in
// production). The transport is intentionally stdlib-only — net/smtp +
// crypto/tls — so this package does not pull in the AWS SDK just for
// transactional mail. STARTTLS is mandatory; plaintext authentication
// is rejected.
//
// Construct via NewSMTPSenderFromEnv to pick up the standard EMAIL_*
// variables, or build a SMTPConfig directly for tests.
type SMTPSender struct {
	cfg SMTPConfig
}

// SMTPConfig is the minimal set of values an SMTP relay needs.
type SMTPConfig struct {
	Host     string        // e.g. email-smtp.eu-central-1.amazonaws.com
	Port     int           // e.g. 587
	Username string        // SES SMTP user (NOT the IAM access key id)
	Password string        // SES SMTP password
	Timeout  time.Duration // hard cap on the entire SMTP exchange
}

// NewSMTPSender builds a sender from an explicit config.
func NewSMTPSender(cfg SMTPConfig) (*SMTPSender, error) {
	if cfg.Host == "" {
		return nil, errors.New("smtp host required")
	}
	if cfg.Port == 0 {
		return nil, errors.New("smtp port required")
	}
	if cfg.Timeout == 0 {
		cfg.Timeout = 15 * time.Second
	}
	return &SMTPSender{cfg: cfg}, nil
}

// NewSMTPSenderFromEnv reads EMAIL_SMTP_HOST / _PORT / _USERNAME /
// _PASSWORD. Returns an error if any required value is missing so the
// runtime fails loudly rather than silently dropping mail.
func NewSMTPSenderFromEnv() (*SMTPSender, error) {
	host := strings.TrimSpace(os.Getenv("EMAIL_SMTP_HOST"))
	if host == "" {
		return nil, errors.New("EMAIL_SMTP_HOST required")
	}
	portStr := strings.TrimSpace(os.Getenv("EMAIL_SMTP_PORT"))
	if portStr == "" {
		portStr = "587"
	}
	port, err := strconv.Atoi(portStr)
	if err != nil {
		return nil, fmt.Errorf("EMAIL_SMTP_PORT not numeric: %w", err)
	}
	user := strings.TrimSpace(os.Getenv("EMAIL_SMTP_USERNAME"))
	pass := os.Getenv("EMAIL_SMTP_PASSWORD")
	if user == "" || pass == "" {
		return nil, errors.New("EMAIL_SMTP_USERNAME and EMAIL_SMTP_PASSWORD required")
	}
	return NewSMTPSender(SMTPConfig{
		Host:     host,
		Port:     port,
		Username: user,
		Password: pass,
	})
}

// Send delivers `msg` over SMTP with STARTTLS + PLAIN auth. The full
// message (headers + body) is built as a multipart/alternative payload
// so HTML-capable clients render HTMLBody and the rest fall back to
// TextBody.
func (s *SMTPSender) Send(ctx context.Context, msg Message) error {
	addr := fmt.Sprintf("%s:%d", s.cfg.Host, s.cfg.Port)
	auth := smtp.PlainAuth("", s.cfg.Username, s.cfg.Password, s.cfg.Host)

	from := buildFromHeader(msg.FromName, msg.FromEmail)
	body := buildMimeBody(from, msg)

	// net/smtp.SendMail handles STARTTLS negotiation internally on the
	// submission port (587). The context timeout is enforced via a
	// goroutine so the call returns when ctx fires even if the upstream
	// server is unresponsive.
	done := make(chan error, 1)
	go func() {
		done <- smtp.SendMail(addr, auth, msg.FromEmail, []string{msg.To}, body)
	}()

	select {
	case err := <-done:
		return err
	case <-time.After(s.cfg.Timeout):
		return fmt.Errorf("smtp send timed out after %s", s.cfg.Timeout)
	case <-ctx.Done():
		return ctx.Err()
	}
}

// TLSConfigForHost returns the TLS config callers can use when wrapping
// the SMTP dial themselves (kept here for symmetry with future SES
// adapters that need explicit TLS configuration).
func TLSConfigForHost(host string) *tls.Config {
	return &tls.Config{ServerName: host, MinVersion: tls.VersionTLS12}
}

func buildFromHeader(name, email string) string {
	if name == "" {
		return email
	}
	return fmt.Sprintf("%q <%s>", name, email)
}

// buildMimeBody assembles a multipart/alternative MIME payload with both
// the text and HTML body parts. Boundary is fixed (content does not
// include it) so output is deterministic for tests.
func buildMimeBody(fromHeader string, msg Message) []byte {
	const boundary = "czechgo-mime-boundary"

	var b strings.Builder
	b.WriteString("From: ")
	b.WriteString(fromHeader)
	b.WriteString("\r\n")
	b.WriteString("To: ")
	b.WriteString(msg.To)
	b.WriteString("\r\n")
	b.WriteString("Subject: ")
	b.WriteString(encodeSubject(msg.Subject))
	b.WriteString("\r\n")
	b.WriteString("MIME-Version: 1.0\r\n")
	b.WriteString("Content-Type: multipart/alternative; boundary=\"")
	b.WriteString(boundary)
	b.WriteString("\"\r\n\r\n")

	if msg.TextBody != "" {
		b.WriteString("--")
		b.WriteString(boundary)
		b.WriteString("\r\n")
		b.WriteString("Content-Type: text/plain; charset=utf-8\r\n")
		b.WriteString("Content-Transfer-Encoding: 8bit\r\n\r\n")
		b.WriteString(msg.TextBody)
		b.WriteString("\r\n")
	}

	if msg.HTMLBody != "" {
		b.WriteString("--")
		b.WriteString(boundary)
		b.WriteString("\r\n")
		b.WriteString("Content-Type: text/html; charset=utf-8\r\n")
		b.WriteString("Content-Transfer-Encoding: 8bit\r\n\r\n")
		b.WriteString(msg.HTMLBody)
		b.WriteString("\r\n")
	}

	b.WriteString("--")
	b.WriteString(boundary)
	b.WriteString("--\r\n")

	return []byte(b.String())
}

// encodeSubject wraps non-ASCII subjects with RFC 2047 UTF-8 base64
// encoding so VI diacritics survive transit through old MTAs. Pure-
// ASCII subjects are returned unchanged.
func encodeSubject(subject string) string {
	for _, r := range subject {
		if r > 127 {
			return mimeEncode(subject)
		}
	}
	return subject
}

func mimeEncode(s string) string {
	return "=?UTF-8?B?" + base64.StdEncoding.EncodeToString([]byte(s)) + "?="
}
