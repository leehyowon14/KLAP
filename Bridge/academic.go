package main

import (
	"context"
	"github.com/leehyowon14/KLAP-cli/internal/app"
)

func init() {
	handlers["academic-list"] = func(ctx context.Context, s *app.Service, r request) error {
		value, err := s.AcademicList(ctx, app.AcademicListOptions{Year: r.Year, Refresh: true})
		if err == nil {
			emit("result", value)
		}
		return err
	}
}
