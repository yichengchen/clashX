import subprocess
import os
import re
from build_clash import get_full_version
from build_clash import build_clash


def upgrade_version(current_version):
    string = open('go.mod').read()
    string = string.replace(current_version, "dev")
    file = open("go.mod", "w")
    file.write(string)


def install():
    subprocess.check_output("go mod download", shell=True)
    subprocess.check_output("go mod tidy", shell=True)


if __name__ == '__main__':
    print("start")
    current = get_full_version()
    print("current version:", current)
    upgrade_version(current)
    install()
    new_version = get_full_version()
    print("new version:", new_version, ",start building")
    build_clash(new_version)
