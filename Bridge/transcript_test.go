package main

import (
	"github.com/leehyowon14/KLAP-cli/internal/app"
	"os"
	"path/filepath"
	"testing"
)

func TestTranscriptExists(t *testing.T) {
	video := filepath.Join(t.TempDir(), "lecture.mp4")
	text := app.TranscriptPathForDownload(video)
	if transcriptExists(video) {
		t.Fatal("missing transcript marked complete")
	}
	os.WriteFile(text, nil, 0600)
	if transcriptExists(video) {
		t.Fatal("empty transcript marked complete")
	}
	os.WriteFile(text, []byte("전사 내용"), 0600)
	if !transcriptExists(video) {
		t.Fatal("valid transcript not found")
	}
	os.Remove(text)
	os.Mkdir(text, 0700)
	if transcriptExists(video) {
		t.Fatal("directory marked complete")
	}
}
