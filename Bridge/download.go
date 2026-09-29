package main

import (
	"context"
	"fmt"
	"github.com/leehyowon14/KLAP-cli/internal/app"
	"path/filepath"
	"strings"
	"sync"
)

type lectureDownloader interface {
	DownloadAllLectures(context.Context, app.LectureDownloadAllOptions) (app.LectureDownloadAllResult, error)
}
type downloadItem struct {
	ID      string
	Path    string
	Bytes   int64
	Skipped bool
	Error   string
}

func runDownloads(ctx context.Context, service lectureDownloader, r request, user app.UserOption, send func(string, any)) error {
	ids := []string{}
	seen := map[string]bool{}
	for _, raw := range r.IDs {
		id := strings.TrimSpace(raw)
		if id != "" && !seen[id] {
			ids = append(ids, id)
			seen[id] = true
		}
	}
	if len(ids) == 0 {
		return fmt.Errorf("다운로드할 강의를 선택해 주세요")
	}
	if !filepath.IsAbs(r.Directory) {
		return fmt.Errorf("저장 폴더를 선택해 주세요")
	}
	var mu sync.Mutex
	value, err := service.DownloadAllLectures(ctx, app.LectureDownloadAllOptions{User: user, Dir: r.Directory, Concurrency: 1, LectureIDs: ids, OnProgress: func(p app.LectureDownloadProgress) {
		mu.Lock()
		defer mu.Unlock()
		message := ""
		if p.Err != nil {
			message = p.Err.Error()
		}
		send("download-progress", map[string]any{"ID": p.Lecture.ID, "Stage": p.Stage, "Bytes": p.Bytes, "TotalBytes": p.TotalBytes, "Error": message})
	}})
	if err != nil {
		return err
	}
	if ctx.Err() != nil {
		return ctx.Err()
	}
	results := []downloadItem{}
	found := map[string]bool{}
	for _, item := range value.Items {
		if !seen[item.Lecture.ID] {
			continue
		}
		row := downloadItem{ID: item.Lecture.ID, Path: item.Path, Bytes: item.Bytes, Skipped: item.Skipped}
		if item.Err != nil {
			row.Error = item.Err.Error()
		}
		if row.Error == "" && row.Path == "" {
			row.Error = "다운로드 파일을 확인하지 못했습니다"
		}
		results = append(results, row)
		found[row.ID] = true
	}
	for _, id := range ids {
		if !found[id] {
			results = append(results, downloadItem{ID: id, Error: "선택한 강의를 찾지 못했습니다. 목록을 새로고침해 주세요"})
		}
	}
	send("download-result", results)
	return nil
}
func init() {
	handlers["lecture-download"] = func(ctx context.Context, s *app.Service, r request) error {
		users, err := s.Users(ctx)
		if err != nil {
			return err
		}
		user, account, err := notificationAccount(users)
		if err != nil {
			return err
		}
		if r.ExpectedAccount == "" || r.ExpectedAccount != account {
			return fmt.Errorf("다운로드를 선택한 계정과 현재 계정이 다릅니다")
		}
		return runDownloads(ctx, s, r, user, emit)
	}
}
