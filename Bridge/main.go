package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/leehyowon14/KLAP-cli/internal/app"
	"github.com/leehyowon14/KLAP-cli/internal/bootstrap"
	"os"
	"os/signal"
	"syscall"
	"time"
)

type request struct {
	TimetableName     string
	AcademicName      string
	ReminderName      string
	TimetableExisting bool
	AcademicExisting  bool
	ReminderExisting  bool
	Command           string
	ID                string
	StudentID         string
	Password          string
	IDs               []string
	Decisions         map[string]app.SyncDecision
}
type event struct {
	Kind  string `json:"kind"`
	Data  any    `json:"data,omitempty"`
	Error string `json:"error,omitempty"`
}

func emit(kind string, data any) {
	_ = json.NewEncoder(os.Stdout).Encode(event{Kind: kind, Data: data})
}
func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	var r request
	if err := json.NewDecoder(os.Stdin).Decode(&r); err != nil {
		fail(err)
		return
	}
	s, err := bootstrap.NewService()
	if err != nil {
		fail(err)
		return
	}
	if r.Command != "attend" {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 3*time.Minute)
		defer cancel()
	}
	switch r.Command {
	case "auth":
		err = s.Authenticate(ctx, r.StudentID, r.Password)
		if err == nil {
			emit("done", nil)
		}
	case "users":
		var v []app.UserRow
		v, err = s.Users(ctx)
		if err == nil {
			emit("result", v)
		}
	case "snapshot":
		result := map[string]any{}
		problems := []string{}
		table, e := s.Timetable(ctx, app.TimetableOptions{Refresh: true})
		if e != nil {
			problems = append(problems, e.Error())
		} else {
			result["timetable"] = table
		}
		assignments, e := s.AssignmentList(ctx, app.AssignmentListOptions{Refresh: true})
		if e != nil {
			problems = append(problems, e.Error())
		} else {
			result["assignments"] = assignments
		}
		notices, e := s.NoticeList(ctx, app.NoticeListOptions{Refresh: true})
		if e != nil {
			problems = append(problems, e.Error())
		} else {
			result["notices"] = notices
		}
		lectures, e := s.LectureList(ctx, app.LectureListOptions{Refresh: true})
		if e != nil {
			problems = append(problems, e.Error())
		} else {
			rows := []map[string]any{}
			for _, l := range lectures {
				reason := ""
				if e := app.ValidateLectureAttendance(l, time.Now()); e != nil {
					reason = e.Error()
				}
				rows = append(rows, map[string]any{"row": l, "reason": reason})
			}
			result["lectures"] = rows
		}
		result["errors"] = problems
		emit("result", result)
	case "open":
		var v app.OpenURLResult
		v, err = s.LectureOpenURL(ctx, r.ID, app.UserOption{})
		if err == nil {
			emit("result", v)
		}
	default:
		if handler, ok := handlers[r.Command]; ok {
			err = handler(ctx, s, r)
		} else {
			err = fmt.Errorf("지원하지 않는 명령: %s", r.Command)
		}
	}
	if err != nil {
		fail(err)
	}
}
func fail(err error) {
	_ = json.NewEncoder(os.Stdout).Encode(event{Kind: "error", Error: err.Error()})
	os.Exit(1)
}

var handlers = map[string]func(context.Context, *app.Service, request) error{}
