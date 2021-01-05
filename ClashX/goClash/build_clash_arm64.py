import subprocess
import datetime
import os

def get_version():
    with open('./go.mod') as file:
        for line in file.readlines():
            if "clash-premium" in line:
                return line.split("-")[-1].strip()[:6]
    return "unknown"


def build_clash(version,build_time,arch):
    clang = f"{os.getcwd()}/clangWrap.sh"
    command = f"""
go build -trimpath -ldflags '-X "github.com/Dreamacro/clash/constant.Version={version}" \
-X "github.com/Dreamacro/clash/constant.BuildTime={build_time}"' \
-buildmode=c-archive -o goClash_{arch}.a """
    envs = os.environ.copy()
    envs.update({
        "CC":clang,
        "CXX":clang,
        "GOOS":"darwin",
        "GOARCH":arch,
        "CGO_ENABLED":"1",
        "CGO_LDFLAGS":"-mmacosx-version-min=10.12",
        "CGO_CFLAGS":"-mmacosx-version-min=10.12",
    })    
    subprocess.check_output(command, shell=True,env=envs)



def run():
    version = get_version()
    build_time = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    print("current clash version:", version)
    build_clash(version,build_time,"arm64")

if __name__ == "__main__":
    run()
