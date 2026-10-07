package main

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func testServer(cfg config) *server {
	return newServer(cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func TestHealthz(t *testing.T) {
	s := testServer(config{})
	rr := httptest.NewRecorder()
	s.routes().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rr.Code != http.StatusOK {
		t.Fatalf("healthz: got %d", rr.Code)
	}
}

func TestReadyzReflectsState(t *testing.T) {
	s := testServer(config{})
	h := s.routes()

	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	if rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("readyz before ready: got %d", rr.Code)
	}

	s.ready.Store(true)
	rr = httptest.NewRecorder()
	h.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	if rr.Code != http.StatusOK {
		t.Fatalf("readyz after ready: got %d", rr.Code)
	}
}

func TestHelloRecordsMetrics(t *testing.T) {
	s := testServer(config{})
	h := s.routes()

	for range 3 {
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/api/hello", nil))
		if rr.Code != http.StatusOK {
			t.Fatalf("hello: got %d", rr.Code)
		}
	}

	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	body := rr.Body.String()

	for _, want := range []string{
		`http_requests_total{route="/api/hello",code="200"} 3`,
		`http_request_duration_seconds_count{route="/api/hello"} 3`,
		`http_request_duration_seconds_bucket{route="/api/hello",le="+Inf"} 3`,
		`app_build_info{version="dev"} 1`,
	} {
		if !strings.Contains(body, want) {
			t.Errorf("metrics missing %q\n%s", want, body)
		}
	}
}

func TestFaultInjectionAlwaysFails(t *testing.T) {
	s := testServer(config{errorRate: 1})
	rr := httptest.NewRecorder()
	s.routes().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/api/hello", nil))
	if rr.Code != http.StatusInternalServerError {
		t.Fatalf("expected injected 500, got %d", rr.Code)
	}
}

func TestHistogramBucketsAreCumulative(t *testing.T) {
	s := testServer(config{})
	h := s.routes()
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/api/hello", nil))

	rr = httptest.NewRecorder()
	h.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	// A fast request must be counted in the largest finite bucket too.
	if !strings.Contains(rr.Body.String(), `http_request_duration_seconds_bucket{route="/api/hello",le="5"} 1`) {
		t.Fatalf("bucket le=5 should be cumulative:\n%s", rr.Body.String())
	}
}
