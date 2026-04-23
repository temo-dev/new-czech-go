FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN target_os="${TARGETOS:-linux}" && \
  target_arch="${TARGETARCH:-arm64}" && \
  echo "Building backend for ${target_os}/${target_arch}" && \
  CGO_ENABLED=0 GOOS="${target_os}" GOARCH="${target_arch}" go build -o /out/api ./cmd/api

FROM alpine:3.20 AS runner

RUN apk add --no-cache ca-certificates tzdata wget

WORKDIR /app

COPY --from=builder /out/api /usr/local/bin/api

ENV API_ADDR=:8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null || exit 1

CMD ["api"]
