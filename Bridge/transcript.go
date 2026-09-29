package main

import (
	"context"
	"fmt"
	"github.com/leehyowon14/KLAP-cli/internal/app"
	"os"
	"path/filepath"
)

func transcriptExists(path string) bool {
	info, err := os.Stat(app.TranscriptPathForDownload(path))
	return err == nil && info.Mode().IsRegular() && info.Size() > 0
}
func emitTranscript(v app.LectureTranscriptProgress) {
	message := ""
	if v.Err != nil {
		message = v.Err.Error()
	}
	emit("transcript-progress", map[string]any{"ID": v.Lecture.ID, "Stage": v.Stage, "Path": v.OutputPath, "Error": message})
}
func init() {
	handlers["lecture-transcribe"] = func(ctx context.Context, s *app.Service, r request) error {
		if !filepath.IsAbs(r.Directory) || r.ID == "" {
			return fmt.Errorf("저장된 강의를 선택해 주세요")
		}
		users, err := s.Users(ctx)
		if err != nil {
			return err
		}
		user, account, err := notificationAccount(users)
		if err != nil {
			return err
		}
		if r.ExpectedAccount == "" || r.ExpectedAccount != account {
			return fmt.Errorf("계정이 변경되었습니다")
		}
		files, err := s.DownloadInventory(ctx, app.LectureDownloadAllOptions{User: user, Dir: r.Directory})
		if err != nil {
			return err
		}
		for _, file := range files {
			if file.ID == r.ID {
				s.TranscribeDownloadedLectures(ctx, []app.LectureDownloadItem{{Lecture: app.LectureRow{ID: r.ID}, Path: file.Path}}, app.LectureTranscriptOptions{Locale: r.Locale, OnProgress: emitTranscript})
				if ctx.Err() != nil {
					return ctx.Err()
				}
				emit("transcript-result", true)
				return nil
			}
		}
		return fmt.Errorf("저장된 영상 파일을 찾지 못했습니다")
	}
}
