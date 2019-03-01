package main // import "github.com/yichengchen/clashX/ClashX"
import (
	"C"
	"os"

	"github.com/Dreamacro/clash/hub"
	"github.com/Dreamacro/clash/hub/route"
)

//export run
func run() *C.char {
	if err := hub.Parse(); err != nil {
		return C.CString(err.Error())
	}

	return C.CString("success")
}

//export setUIPath
func setUIPath(path *C.char) {
	route.SetUIPath(C.GoString(path))
}

func main() {
	// enable tls 1.3 and remove when go 1.13
	os.Setenv("GODEBUG", os.Getenv("GODEBUG")+",tls13=1")
}
