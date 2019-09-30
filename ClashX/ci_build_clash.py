import subprocess
import datetime
import plistlib


def get_version():
    with open('./go.mod') as file:
        for line in file.readlines():
            if "require" in line:
                return line.split(" ")[-1].strip()
    return "unknown"


def build_clash(version):
    build_time = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    command = f"""CGO_CFLAGS=-mmacosx-version-min=10.12 \
CGO_LDFLAGS=-mmacosx-version-min=10.10 \
GOBUILD=CGO_ENABLED=0 \
go build -ldflags '-X "github.com/Dreamacro/clash/constant.Version={version}" \
-X "github.com/Dreamacro/clash/constant.BuildTime={build_time}"' \
-buildmode=c-archive """
    subprocess.check_output(command, shell=True)


def write_to_info(version):
    path = "info.plist"

    with open(path, 'rb') as f:
        contents = plistlib.load(f)

    if not contents:
        exit(-1)

    contents["coreVersion"] = version
    with open(path, 'wb') as f:
        plistlib.dump(contents, f, sort_keys=False)


def run():
    version = get_version()
    print("current clash version: ", version)
    build_clash(version)
    print("build static library complete!")
    print("writing info.plist")
    write_to_info(version)
    print("done")


if __name__ == "__main__":
    run()
