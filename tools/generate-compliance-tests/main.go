package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	cases "github.com/open-policy-agent/opa/build/generate-extended-cases"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: main <source-dir>")
		os.Exit(1)
	}

	outputDir := os.Args[1]

	extendedSets, err := cases.LoadIrExtendedTestCases()
	if err != nil {
		panic(err)
	}

	for _, extendedSet := range extendedSets {
		tcJson, err := json.MarshalIndent(extendedSet, "", "\t")
		if err != nil {
			panic(fmt.Errorf("Failed to marchal test case to json: %s\n", err.Error()))
		}

		tPath := strings.Split(extendedSet.Cases[0].Filename, "/")
		folderPath := fmt.Sprintf("%s/%s", outputDir, tPath[len(tPath)-2])
		tcFileName := strings.ReplaceAll(tPath[len(tPath)-1], ".yaml", ".json")

		if err := os.MkdirAll(folderPath, 0755); err != nil {
			panic(err)
		}

		if err := os.WriteFile(fmt.Sprintf("%s/%s", folderPath, tcFileName), tcJson, 0644); err != nil {
			panic(fmt.Errorf("Failed to write test case: %s\n", err.Error()))
		}
	}
}
