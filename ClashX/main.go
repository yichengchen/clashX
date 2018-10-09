package main // import "github.com/yichengchen/clashX/ClashX"

import (
	"C"

	"github.com/Dreamacro/clash/config"
	"github.com/Dreamacro/clash/hub"
	"github.com/Dreamacro/clash/proxy"
	"github.com/Dreamacro/clash/tunnel"
)
import (
	"os"
	"os/signal"
	"syscall"
)

//export run
func run() *C.char {
	tunnel.Instance().Run()
	proxy.Instance().Run()
	hub.Run()

	config.Init()
	err := config.Instance().Parse()
	if err != nil {
		return C.CString(err.Error())

	}

	return C.CString("success")
}

//export updateAllConfig
func updateAllConfig() *C.char {
	err := config.Instance().Parse()
	if err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

func main() {
	run()
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
}
