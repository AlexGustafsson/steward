FROM --platform=${BUILDPLATFORM} golang:1.26.0@sha256:c83e68f3ebb6943a2904fa66348867d108119890a2c6a2e6f07b38d0eb6c25c5 AS builder

WORKDIR /src

# Use the toolchain specified in go.mod, or newer
ENV GOTOOLCHAIN=auto

COPY go.mod go.sum .
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
  go mod download && go mod verify

COPY cmd cmd
COPY internal internal

ARG TARGETARCH
ARG TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
  GOARCH=${TARGETARCH} GOOS=${TARGETOS} CGO_ENABLED=0 go build -a -ldflags="-s -w" -o steward cmd/steward/*.go

FROM scratch AS export

COPY --from=builder /src/steward steward

FROM export

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENV PATH=/

ENTRYPOINT ["steward"]
