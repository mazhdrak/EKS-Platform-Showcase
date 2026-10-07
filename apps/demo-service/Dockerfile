# syntax=docker/dockerfile:1
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags="-s -w -X main.version=${VERSION}" -o /out/demo-service .

# Distroless static: no shell, no package manager, runs as non-root (65532).
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/demo-service /demo-service
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/demo-service"]
