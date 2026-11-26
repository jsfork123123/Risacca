"""Boot a Risacca installer ISO in a diskless VM and check the welcome screen."""

import argparse
import subprocess
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageOps


def read_screen(path):
    with Image.open(path) as image:
        # The console font is small and the active button has inverted colours.
        gray = ImageOps.grayscale(image)
        gray.resize((gray.width * 2, gray.height * 2)).save(path.with_suffix(".png"))
    result = subprocess.run(
        ["tesseract", str(path.with_suffix(".png")), "stdout", "--psm", "6"],
        capture_output=True, text=True, check=True,
    )
    return " ".join(result.stdout.lower().split())


def boot(image, firmware):
    with tempfile.TemporaryDirectory(prefix="risacca-boot-") as folder:
        work = Path(folder)
        command = [
            "qemu-system-x86_64", "-machine", "q35,accel=kvm:tcg",
            "-m", "2048", "-smp", "2", "-boot", "order=d",
            "-display", "none", "-monitor", "stdio", "-serial", "none",
            "-nic", "none", "-no-reboot", "-cdrom", str(image),
        ]
        if firmware == "UEFI":
            command += [
                "-drive", "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd",
                "-drive", "if=pflash,format=raw,snapshot=on,file=/usr/share/OVMF/OVMF_VARS_4M.fd",
            ]
        print(f"Booting {firmware} from {image.name}", flush=True)
        with subprocess.Popen(command, cwd=work, stdin=subprocess.PIPE,
                              stdout=subprocess.DEVNULL, text=True) as vm:
            try:
                deadline = time.monotonic() + 300
                last_text = ""
                while time.monotonic() < deadline:
                    time.sleep(5)
                    if vm.poll() is not None:
                        raise RuntimeError(f"{firmware}: QEMU exited with {vm.returncode}")
                    screen = work / "console.ppm"
                    screen.unlink(missing_ok=True)
                    vm.stdin.write("screendump console.ppm\n")
                    vm.stdin.flush()
                    for _ in range(40):
                        time.sleep(0.1)
                        try:
                            last_text = read_screen(screen)
                            break
                        except OSError:
                            # The monitor creates the image asynchronously.
                            continue
                    else:
                        raise RuntimeError(f"{firmware}: QEMU did not return a screen")
                    # The welcome dialog asks this question and also offers a shell.
                    question = "would you like to begin" in last_text or "use the live system" in last_text
                    buttons = "shell" in last_text and "live system" in last_text
                    if "install" in last_text and (question or buttons):
                        print(f"{firmware}: reached the installer welcome screen.\n{last_text}", flush=True)
                        return
                raise RuntimeError(f"{firmware}: installer timed out. Last screen: {last_text}")
            finally:
                if vm.poll() is None:
                    vm.terminate()
                    try:
                        vm.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        vm.kill()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iso", type=Path)
    args = parser.parse_args()
    image = args.iso.resolve(strict=True)
    for firmware in ("BIOS", "UEFI"):
        boot(image, firmware)
