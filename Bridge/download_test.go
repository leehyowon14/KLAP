package main

import (
	"context"
	"errors"
	"github.com/leehyowon14/KLAP-cli/internal/app"
	"testing"
)

type fakeDownloader struct {
	calls  int
	opts   app.LectureDownloadAllOptions
	result app.LectureDownloadAllResult
	err    error
}

func (f *fakeDownloader) DownloadAllLectures(ctx context.Context, o app.LectureDownloadAllOptions) (app.LectureDownloadAllResult, error) {
	f.calls++
	f.opts = o
	return f.result, f.err
}
func TestDownloadSelection(t *testing.T) {
	fake := &fakeDownloader{}
	for _, r := range []request{{IDs: nil, Directory: "/tmp"}, {IDs: []string{" "}, Directory: "/tmp"}, {IDs: []string{"a"}, Directory: "relative"}} {
		if runDownloads(context.Background(), fake, r, app.UserOption{}, func(string, any) { t.Fatal("unexpected output") }) == nil {
			t.Fatal("invalid request accepted")
		}
	}
	if fake.calls != 0 {
		t.Fatal("empty selection must never download all lectures")
	}
	fake.result = app.LectureDownloadAllResult{Items: []app.LectureDownloadItem{{Lecture: app.LectureRow{ID: "a"}, Path: "/tmp/a.mp4"}, {Lecture: app.LectureRow{ID: "b"}, Err: errors.New("지원하지 않음")}}}
	var rows []downloadItem
	err := runDownloads(context.Background(), fake, request{IDs: []string{"a", "a", " b ", "missing"}, Directory: "/tmp"}, app.UserOption{}, func(kind string, data any) { rows = data.([]downloadItem) })
	if err != nil || len(fake.opts.LectureIDs) != 3 || fake.opts.Concurrency != 1 || len(rows) != 3 {
		t.Fatalf("selection/result mismatch: %v", err)
	}
	if rows[0].Error != "" || rows[1].Error != "지원하지 않음" || rows[2].Error == "" {
		t.Fatal("partial failure or missing selection lost")
	}
}
func TestDownloadCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err := runDownloads(ctx, &fakeDownloader{}, request{IDs: []string{"a"}, Directory: "/tmp"}, app.UserOption{}, func(string, any) { t.Fatal("cancelled run reported completion") })
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected cancellation: %v", err)
	}
}

func TestDownloadConcurrency(t *testing.T) {
	for _, pair := range [][2]int{{-1, 1}, {0, 1}, {1, 1}, {3, 3}, {8, 8}, {100, 8}} {
		if got := downloadConcurrency(pair[0]); got != pair[1] {
			t.Fatalf("limit %d: %d", pair[0], got)
		}
	}
	fake := &fakeDownloader{}
	_ = runDownloads(context.Background(), fake, request{IDs: []string{"a"}, Directory: "/tmp", Concurrency: 6, Adaptive: true}, app.UserOption{}, func(string, any) {})
	if fake.opts.Concurrency != 6 || !fake.opts.Adaptive {
		t.Fatal("adaptive options lost")
	}
}
