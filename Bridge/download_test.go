package main

import (
	"context"
	"errors"
	"github.com/leehyowon14/KLAP-cli/internal/app"
	"testing"
)

type fakeDownloader struct {
	progress []app.LectureDownloadProgress
	calls    int
	opts     app.LectureDownloadAllOptions
	result   app.LectureDownloadAllResult
	err      error
}

func (f *fakeDownloader) DownloadAllLectures(ctx context.Context, o app.LectureDownloadAllOptions) (app.LectureDownloadAllResult, error) {
	f.calls++
	f.opts = o
	for _, p := range f.progress {
		if o.OnProgress != nil {
			o.OnProgress(p)
		}
	}
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

type fakePipeline struct{}

func (fakePipeline) RunLectureDownloadPipeline(ctx context.Context, o app.LectureDownloadPipelineOptions) (app.LectureDownloadPipelineResult, error) {
	if !o.Transcribe || o.TranscriptLocale != "ko-KR" || o.TranscriptConcurrency != 1 {
		panic("pipeline options")
	}
	o.OnEvent(app.LecturePipelineEvent{Download: &app.LectureDownloadProgress{Lecture: app.LectureRow{ID: "a"}, Stage: app.LectureStageDone}})
	o.OnEvent(app.LecturePipelineEvent{Transcript: &app.LectureTranscriptProgress{Lecture: app.LectureRow{ID: "a"}, Stage: app.LectureStageTranscriptError, Err: errors.New("speech unavailable")}})
	return app.LectureDownloadPipelineResult{Download: app.LectureDownloadAllResult{Items: []app.LectureDownloadItem{{Lecture: app.LectureRow{ID: "a"}, Path: "/tmp/a.mp4"}}}}, nil
}
func TestTranscriptFailurePreservesDownload(t *testing.T) {
	progress := false
	transcript := false
	p := pipelineDownloader{service: fakePipeline{}, locale: "ko-KR", send: func(kind string, data any) {
		v := data.(map[string]any)
		transcript = kind == "transcript-progress" && v["Error"] == "speech unavailable"
	}}
	result, err := p.DownloadAllLectures(context.Background(), app.LectureDownloadAllOptions{OnProgress: func(app.LectureDownloadProgress) { progress = true }})
	if err != nil || !progress || !transcript || len(result.Items) != 1 || result.Items[0].Path != "/tmp/a.mp4" {
		t.Fatal("pipeline lost completed download or transcript failure")
	}
}

func TestProgressThrottleKeepsTransitions(t *testing.T) {
	f := &fakeDownloader{}
	for i := int64(0); i < 100; i++ {
		f.progress = append(f.progress, app.LectureDownloadProgress{Lecture: app.LectureRow{ID: "a"}, Stage: app.LectureStageDownload, Bytes: i})
	}
	for _, stage := range []app.LectureTransferStage{"paused", app.LectureStageDownload, app.LectureStageDone} {
		f.progress = append(f.progress, app.LectureDownloadProgress{Lecture: app.LectureRow{ID: "a"}, Stage: stage, Bytes: 100})
	}
	stages := []app.LectureTransferStage{}
	_ = runDownloads(context.Background(), f, request{IDs: []string{"a"}, Directory: "/tmp"}, app.UserOption{}, func(kind string, value any) {
		if kind == "download-progress" {
			stages = append(stages, value.(map[string]any)["Stage"].(app.LectureTransferStage))
		}
	})
	if len(stages) != 4 || stages[1] != "paused" || stages[3] != app.LectureStageDone {
		t.Fatalf("transition events lost: %v", stages)
	}
}
