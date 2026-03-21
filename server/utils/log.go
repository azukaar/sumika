package utils

import (
	"fmt"
	"log"
	"os"

	"github.com/azukaar/sumika/server/config"
)

type LoggingLevel string

const (
	DEBUG LogLevel = iota
	INFO
	WARNING
	ERROR
	FATAL
)

var LoggingLevelLabels = map[LoggingLevel]LogLevel{
	"DEBUG":   DEBUG,
	"INFO":    INFO,
	"WARNING": WARNING,
	"ERROR":   ERROR,
	"FATAL":   FATAL,
}

var (
	Reset    = "\033[0m"
	Bold     = "\033[1m"
	nRed     = "\033[31m"
	nGreen   = "\033[32m"
	nYellow  = "\033[33m"
	nBlue    = "\033[34m"
	nPurple  = "\033[35m"
	nCyan    = "\033[36m"
	nGray    = "\033[37m"
	nWhite   = "\033[97m"
	nMagenta = "\033[95m"
	nBlack   = "\033[30m"
	bRed     = "\033[41m"
	bGreen   = "\033[42m"
	bYellow  = "\033[43m"
	bBlue    = "\033[44m"
	bMagenta = "\033[45m"
	bCyan    = "\033[46m"
	bGray    = "\033[47m"
	bWhite   = "\033[107m"
	bPurple  = "\033[45m"
)

type LogLevel int

func RawLogMessage(level LogLevel, prefix, prefixColor, color, message string) {
	ll, ok := LoggingLevelLabels[LoggingLevel(config.GetConfig().Logging.Level)]
	if !ok {
		ll = INFO
	}
	if ll <= level {
		logString := prefixColor + Bold + prefix + Reset + " " + color + message + Reset
		log.Println(logString)
	}
}

func Debug(message string) {
	RawLogMessage(DEBUG, "[DEBUG]", bPurple, nPurple, message)
}

func Log(message string) {
	RawLogMessage(INFO, "[INFO] ", bBlue, nBlue, message)
}

func LogReq(message string) {
	RawLogMessage(INFO, "[REQ]  ", bGreen, nGreen, message)
}

func Warn(message string) {
	RawLogMessage(WARNING, "[WARN] ", bYellow, nYellow, message)
}

func Error(message string, err error) {
	errStr := ""
	if err != nil {
		errStr = err.Error()
		RawLogMessage(ERROR, "[ERROR]", bRed, nRed, message+" : "+errStr)
	} else {
		RawLogMessage(ERROR, "[ERROR]", bRed, nRed, message)
	}
}

func Fatal(message string, err error) {
	errStr := ""
	if err != nil {
		errStr = err.Error()
		RawLogMessage(FATAL, "[FATAL]", bRed, nRed, message+" : "+errStr)
	} else {
		RawLogMessage(FATAL, "[FATAL]", bRed, nRed, message)
	}

	os.Exit(1)
}

func DoWarn(format string, a ...interface{}) string {
	message := fmt.Sprintf(format, a...)
	return fmt.Sprintf("%s%s[WARN]%s %s%s%s", bYellow, nBlack, Reset, nYellow, message, Reset)
}

func DoErr(format string, a ...interface{}) string {
	message := fmt.Sprintf(format, a...)
	return fmt.Sprintf("%s%s[ERROR]%s %s%s%s", bRed, nWhite, Reset, nRed, message, Reset)
}

func DoSuccess(format string, a ...interface{}) string {
	message := fmt.Sprintf(format, a...)
	return fmt.Sprintf("%s%s[SUCCESS]%s %s%s%s", bGreen, nBlack, Reset, nGreen, message, Reset)
}
