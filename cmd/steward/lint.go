package main

import (
	"bufio"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/urfave/cli/v3"
)

var lintRules = []SarifRule{
	{
		ID:   "STEWARD_AUDIO_001",
		Name: "The audio is missing",
		ShortDescription: SarifMessage{
			Text: "Ensure that the track contains audio",
		},
		DefaultConfiguration: SarifRuleConfiguration{
			Level: SarifLevelError,
		},
		Check: func(e indexing.Entry) bool {
			return e.AudioDigest != indexing.EmptyAudioDigest
		},
	},
	{
		ID:   "STEWARD_MISSING_META_001",
		Name: "Missing cover art",
		ShortDescription: SarifMessage{
			Text: "Ensure that cover art is included",
		},
		DefaultConfiguration: SarifRuleConfiguration{
			Level: SarifLevelWarning,
		},
		Check: func(e indexing.Entry) bool {
			return e.PictureDigest != indexing.EmptyPictureDigest
		},
	},
	missingMetaLintRule("STEWARD_MISSING_META_002", "ALBUM", SarifLevelError),
	missingMetaLintRule("STEWARD_MISSING_META_003", "ALBUMARTIST", SarifLevelError),
	missingMetaLintRule("STEWARD_MISSING_META_004", "ARTIST", SarifLevelError),
	missingMetaLintRule("STEWARD_MISSING_META_005", "ARTISTS", SarifLevelError),
	missingMetaLintRule("STEWARD_MISSING_META_006", "BARCODE", SarifLevelWarning),
	missingMetaLintRule("STEWARD_MISSING_META_007", "CATALOGNUMBER", SarifLevelWarning),
	missingMetaLintRule("STEWARD_MISSING_META_008", "LABEL", SarifLevelWarning),
	missingMetaLintRule("STEWARD_MISSING_META_009", "MEDIA", SarifLevelWarning),
	missingMetaLintRule("STEWARD_MISSING_META_010", "RELEASECOUNTRY", SarifLevelWarning),
	missingMetaLintRule("STEWARD_MISSING_META_011", "RELEASEDATE", SarifLevelWarning),
	missingMetaLintRule("STEWARD_MISSING_META_012", "RELEASESTATUS", SarifLevelNote),
	missingMetaLintRule("STEWARD_MISSING_META_013", "RELEASETYPE", SarifLevelNote),
	missingMetaLintRule("STEWARD_MISSING_META_014", "TITLE", SarifLevelError),
	missingMetaLintRule("STEWARD_MISSING_META_015", "TOTALTRACKS", SarifLevelNote),
	missingMetaLintRule("STEWARD_MISSING_META_016", "TRACKNUMBER", SarifLevelNote),
	missingMetaLintRule("STEWARD_MISSING_META_017", "TRACKTOTAL", SarifLevelNote),
	missingMetaLintRule("STEWARD_MISSING_META_018", "GENRE", SarifLevelNote),

	{
		ID:   "STEWARD_UNLIKELY_META_001",
		Name: "Unlikely release country",
		ShortDescription: SarifMessage{
			Text: "The release country is unlikely for this release",
		},
		DefaultConfiguration: SarifRuleConfiguration{
			Level: SarifLevelWarning,
		},
		Check: func(e indexing.Entry) bool {
			for _, v := range e.Metadata {
				k, v, _ := strings.Cut(v, "=")
				if k == "RELEASECOUNTRY" && v == "JP" {
					return false
				}
			}
			return true
		},
	},
	{
		ID:   "STEWARD_UNLIKELY_META_002",
		Name: "Unlikely media",
		ShortDescription: SarifMessage{
			Text: "The media is unlikely for this release",
		},
		DefaultConfiguration: SarifRuleConfiguration{
			Level: SarifLevelWarning,
		},
		Check: func(e indexing.Entry) bool {
			expected := []string{
				"CD",
				"CD-R",
				"Copy Control CD",
				"Enhanced CD",
			}
			for _, v := range e.Metadata {
				k, v, _ := strings.Cut(v, "=")
				if k == "MEDIA" && !slices.Contains(expected, v) {
					return false
				}
			}
			return true
		},
	},

	// TODO:
	// - releasedate is unlikely (before CDs were introduced)
	// - artists order to match artist order
	// - COMPILATION tag if there are more than one artist in a disc?
}

func missingMetaLintRule(id string, field string, level SarifLevel) SarifRule {
	return SarifRule{
		ID:   id,
		Name: fmt.Sprintf("Missing %s metadata entry", field),
		ShortDescription: SarifMessage{
			Text: fmt.Sprintf("Ensure that a metadata entry for '%s' is set", field),
		},
		DefaultConfiguration: SarifRuleConfiguration{
			Level: level,
		},
		Check: func(e indexing.Entry) bool {
			for _, v := range e.Metadata {
				if strings.HasPrefix(v, field+"=") {
					return true
				}
			}
			return false
		},
	}
}

func LintAction(ctx context.Context, cmd *cli.Command) error {
	// When upload, an index is not required if a just-in-time index is created.
	// Use "-" convention to signal reading from stdin
	indexPath := cmd.StringArg("index")
	var reader io.ReadCloser
	if indexPath == "-" {
		slog.Debug("Reading index from stdin")
		reader = io.NopCloser(os.Stdin)
	} else if indexPath != "" {
		slog.Debug("Reading index from file")
		file, err := os.Open(indexPath)
		if err != nil {
			slog.Error("Failed to read index", slog.Any("error", err))
			return ErrExit // TODO Actual error
		}
		defer file.Close()
		reader = file

		if filepath.Ext(indexPath) == ".gz" {
			var err error
			reader, err = gzip.NewReader(reader)
			if err != nil {
				slog.Error("Failed to read index", slog.Any("error", err))
				return ErrExit // TODO Actual error
			}
		}
	} else {
		return fmt.Errorf("missing required index")
	}

	run := SarifRun{
		Tool: SarifTool{
			Driver: SarifDriver{
				Name:    "steward",
				Version: "0.1.0",
				Rules:   lintRules,
			},
		},
		Results: []SarifResult{},
	}

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		var entry indexing.Entry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			slog.Error("Failed to parse index", slog.Any("error", err))
			break
		}

		run.Results = append(run.Results, lint(entry)...)
	}

	result := &Sarif{
		Schema:  "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",
		Version: "2.1.0",
		Runs:    []SarifRun{run},
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(result)
}

type SarifLevel string

const (
	SarifLevelNone    SarifLevel = "none"
	SarifLevelNote    SarifLevel = "note"
	SarifLevelWarning SarifLevel = "warning"
	SarifLevelError   SarifLevel = "error"
)

type Sarif struct {
	Schema  string     `json:"$schema"`
	Version string     `json:"version"`
	Runs    []SarifRun `json:"runs"`
}

type SarifRun struct {
	Tool    SarifTool     `json:"tool"`
	Results []SarifResult `json:"results,omitempty"`
}

type SarifTool struct {
	Driver SarifDriver `json:"driver"`
}

type SarifDriver struct {
	Name    string      `json:"name"`
	Version string      `json:"version"`
	Rules   []SarifRule `json:"rules"`
}

type SarifRule struct {
	ID                   string                 `json:"id"`
	Name                 string                 `json:"name"`
	ShortDescription     SarifMessage           `json:"shortDescription"`
	FullDescription      SarifMessage           `json:"fullDescription,omitzero"`
	DefaultConfiguration SarifRuleConfiguration `json:"defaultConfiguration"`

	// Check is a function that returns true if the rule passes, false otherwise.
	Check func(indexing.Entry) bool `json:"-"`
}

type SarifMessage struct {
	Text string `json:"text"`
}

type SarifRuleConfiguration struct {
	Level SarifLevel `json:"level"`
}

type SarifResult struct {
	RuleID    string                 `json:"ruleId"`
	Level     SarifLevel             `json:"level"`
	Locations []SarifLogicalLocation `json:"locations"`
}

type SarifLogicalLocation struct {
	Kind               string `json:"kind"`
	FullyQualifiedName string `json:"fullyQualifiedName"`
}

func lint(entry indexing.Entry) []SarifResult {
	result := make([]SarifResult, 0)

	appendRule := func(rule SarifRule, name string) {
		result = append(result, SarifResult{
			RuleID: rule.ID,
			Level:  rule.DefaultConfiguration.Level,
			Locations: []SarifLogicalLocation{
				{
					Kind:               "indexEntry",
					FullyQualifiedName: name,
				},
			},
		})
	}

	for _, rule := range lintRules {
		ok := rule.Check(entry)
		if !ok {
			appendRule(rule, entry.Name)
		}
	}

	return result
}
