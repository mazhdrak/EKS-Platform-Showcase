package main

import (
	"fmt"
	"io"
	"sort"
	"strings"
	"sync"
	"time"
)

// Minimal Prometheus text-format metrics with no external dependencies.
// Exposes:
//   http_requests_total{route,code}
//   http_request_duration_seconds{route} (histogram)
//   app_build_info{version}

var defaultBuckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5}

type histogram struct {
	counts []uint64 // one per bucket, cumulative computed at render time
	sum    float64
	total  uint64
}

type Metrics struct {
	mu        sync.Mutex
	version   string
	requests  map[[2]string]uint64 // {route, code} -> count
	durations map[string]*histogram
}

func NewMetrics(version string) *Metrics {
	return &Metrics{
		version:   version,
		requests:  make(map[[2]string]uint64),
		durations: make(map[string]*histogram),
	}
}

func (m *Metrics) Observe(route string, code int, d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.requests[[2]string{route, fmt.Sprint(code)}]++

	h, ok := m.durations[route]
	if !ok {
		h = &histogram{counts: make([]uint64, len(defaultBuckets))}
		m.durations[route] = h
	}
	s := d.Seconds()
	for i, b := range defaultBuckets {
		if s <= b {
			h.counts[i]++
			break
		}
	}
	h.sum += s
	h.total++
}

func (m *Metrics) Render(w io.Writer) {
	m.mu.Lock()
	defer m.mu.Unlock()

	var b strings.Builder

	b.WriteString("# HELP app_build_info Build information.\n# TYPE app_build_info gauge\n")
	fmt.Fprintf(&b, "app_build_info{version=%q} 1\n", m.version)

	b.WriteString("# HELP http_requests_total Total HTTP requests by route and status code.\n# TYPE http_requests_total counter\n")
	keys := make([][2]string, 0, len(m.requests))
	for k := range m.requests {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		if keys[i][0] != keys[j][0] {
			return keys[i][0] < keys[j][0]
		}
		return keys[i][1] < keys[j][1]
	})
	for _, k := range keys {
		fmt.Fprintf(&b, "http_requests_total{route=%q,code=%q} %d\n", k[0], k[1], m.requests[k])
	}

	b.WriteString("# HELP http_request_duration_seconds HTTP request latency.\n# TYPE http_request_duration_seconds histogram\n")
	routes := make([]string, 0, len(m.durations))
	for r := range m.durations {
		routes = append(routes, r)
	}
	sort.Strings(routes)
	for _, r := range routes {
		h := m.durations[r]
		var cum uint64
		for i, le := range defaultBuckets {
			cum += h.counts[i]
			fmt.Fprintf(&b, "http_request_duration_seconds_bucket{route=%q,le=%q} %d\n", r, fmt.Sprint(le), cum)
		}
		fmt.Fprintf(&b, "http_request_duration_seconds_bucket{route=%q,le=\"+Inf\"} %d\n", r, h.total)
		fmt.Fprintf(&b, "http_request_duration_seconds_sum{route=%q} %g\n", r, h.sum)
		fmt.Fprintf(&b, "http_request_duration_seconds_count{route=%q} %d\n", r, h.total)
	}

	io.WriteString(w, b.String())
}
