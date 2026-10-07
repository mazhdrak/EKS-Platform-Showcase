// demo-service is a deliberately small HTTP service used to exercise the
// platform: health probes, Prometheus metrics, structured logs, graceful
// shutdown and a fault-injection knob for demonstrating SLO burn alerts.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"math/rand/v2"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync/atomic"
	"syscall"
	"time"
)

var version = "dev" // overridden at build time via -ldflags

type config struct {
	addr          string
	errorRate     float64       // 0..1, share of /api/* requests that return 500
	extraLatency  time.Duration // added to every /api/* request
	shutdownGrace time.Duration
}

func loadConfig() config {
	c := config{
		addr:          envOr("LISTEN_ADDR", ":8080"),
		shutdownGrace: 20 * time.Second,
	}
	if v, err := strconv.ParseFloat(os.Getenv("FAULT_ERROR_RATE"), 64); err == nil && v >= 0 && v <= 1 {
		c.errorRate = v
	}
	if v, err := time.ParseDuration(os.Getenv("FAULT_EXTRA_LATENCY")); err == nil && v >= 0 {
		c.extraLatency = v
	}
	return c
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

type server struct {
	cfg     config
	log     *slog.Logger
	metrics *Metrics
	ready   atomic.Bool
}

func newServer(cfg config, log *slog.Logger) *server {
	return &server{cfg: cfg, log: log, metrics: NewMetrics(version)}
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		if !s.ready.Load() {
			http.Error(w, "not ready", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ready"))
	})
	mux.HandleFunc("GET /metrics", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		s.metrics.Render(w)
	})
	mux.Handle("GET /api/hello", s.instrument("/api/hello", http.HandlerFunc(s.hello)))
	return mux
}

func (s *server) hello(w http.ResponseWriter, r *http.Request) {
	if s.cfg.extraLatency > 0 {
		select {
		case <-time.After(s.cfg.extraLatency):
		case <-r.Context().Done():
			return
		}
	}
	if s.cfg.errorRate > 0 && rand.Float64() < s.cfg.errorRate {
		http.Error(w, `{"error":"injected fault"}`, http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"message": "hello from the platform",
		"version": version,
	})
}

type statusRecorder struct {
	http.ResponseWriter
	code int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
}

func (s *server) instrument(route string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, code: http.StatusOK}
		next.ServeHTTP(rec, r)
		d := time.Since(start)
		s.metrics.Observe(route, rec.code, d)
		s.log.Info("request",
			"route", route, "method", r.Method, "status", rec.code,
			"duration_ms", d.Milliseconds(), "remote", r.RemoteAddr)
	})
}

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg := loadConfig()
	s := newServer(cfg, log)

	srv := &http.Server{
		Addr:              cfg.addr,
		Handler:           s.routes(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Info("starting", "addr", cfg.addr, "version", version,
			"fault_error_rate", cfg.errorRate, "fault_extra_latency", cfg.extraLatency.String())
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("listen failed", "err", err)
			os.Exit(1)
		}
	}()
	s.ready.Store(true)

	<-ctx.Done()
	// Fail readiness first so the endpoint is removed from the Service
	// before connections are drained.
	s.ready.Store(false)
	log.Info("shutting down")
	time.Sleep(5 * time.Second)

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.shutdownGrace)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("graceful shutdown failed", "err", err)
	}
}
