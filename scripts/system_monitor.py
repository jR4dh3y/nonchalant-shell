#!/usr/bin/env python3
import time
import sys
import os
import json
import subprocess
import re


class SystemMonitor:
    def __init__(self, disks=[]):
        self.prev_cpu_total = 0
        self.prev_cpu_idle = 0
        self.prev_network_rx = None
        self.prev_network_tx = None
        self.prev_network_time = None
        self.monitored_disks = disks
        self.cpu_model = self._detect_cpu_model()
        self.gpu_info = self._detect_gpus()
        self.disk_types = self._detect_disk_types(disks)

    def _detect_cpu_model(self):
        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "model name" in line:
                        model = line.split(":", 1)[1].strip()
                        model = re.sub(
                            r" (?:CPU|FPU|APU|Processor|Dual-Core|Quad-Core|Six-Core|Eight-Core|Ten-Core|[0-9]+-Core)$",
                            "",
                            model,
                            flags=re.I,
                        )
                        model = re.sub(r" w/ Radeon.*$", "", model)
                        model = re.sub(r" with Radeon.*$", "", model)
                        model = re.sub(r" @.*$", "", model)
                        return " ".join(model.split())
        except:
            pass
        return "Unknown CPU"

    def _detect_gpus(self):
        gpus = []
        pci_base = "/sys/bus/pci/devices"
        vendor_names = {
            "0x10de": "nvidia",
            "0x1002": "amd",
            "0x8086": "intel",
        }

        if not os.path.exists(pci_base):
            return gpus

        for pci_id in sorted(os.listdir(pci_base)):
            device_path = os.path.join(pci_base, pci_id)
            try:
                with open(os.path.join(device_path, "class"), "r") as f:
                    device_class = f.read().strip().lower()
                if not device_class.startswith("0x03"):
                    continue

                with open(os.path.join(device_path, "vendor"), "r") as f:
                    vendor_id = f.read().strip().lower()
            except (OSError, ValueError):
                continue

            vendor = vendor_names.get(vendor_id, "unknown")
            gpus.append(
                {
                    "vendor": vendor,
                    "name": self._detect_gpu_name(pci_id, vendor),
                    "pci_id": pci_id,
                    "card": self._find_drm_card(device_path),
                }
            )
        return gpus

    def _detect_gpu_name(self, pci_id, vendor):
        fallback = f"{vendor.upper()} GPU" if vendor != "unknown" else "GPU"
        try:
            output = subprocess.check_output(
                ["lspci", "-D", "-s", pci_id],
                stderr=subprocess.DEVNULL,
                text=True,
            ).strip()
            description = output.split(": ", 1)[-1]
            description = re.sub(r"\s+\(rev [^)]+\)$", "", description)

            product_names = re.findall(
                r"\[((?:GeForce|Radeon|Arc|Iris|UHD)[^]]+)\]", description, re.I
            )
            if product_names:
                return product_names[-1]

            prefixes = {
                "nvidia": r"^NVIDIA Corporation\s+",
                "amd": r"^Advanced Micro Devices, Inc\. \[AMD/ATI\]\s+",
                "intel": r"^Intel Corporation\s+",
            }
            return re.sub(prefixes.get(vendor, r"^$"), "", description) or fallback
        except (OSError, subprocess.SubprocessError):
            return fallback

    def _find_drm_card(self, pci_device_path):
        drm_base = "/sys/class/drm"
        if not os.path.exists(drm_base):
            return ""

        target = os.path.realpath(pci_device_path)
        for card in sorted(os.listdir(drm_base)):
            if not re.fullmatch(r"card\d+", card):
                continue
            if os.path.realpath(os.path.join(drm_base, card, "device")) == target:
                return card
        return ""

    def _get_pci_driver(self, pci_id):
        driver_path = f"/sys/bus/pci/devices/{pci_id}/driver"
        if not os.path.exists(driver_path):
            return "none"
        return os.path.basename(os.path.realpath(driver_path))

    def _detect_disk_types(self, disks):
        types = {}
        for mount in disks:
            types[mount] = "unknown"
            try:
                with open("/proc/mounts", "r") as f:
                    for line in f:
                        parts = line.split()
                        if parts[1] == mount:
                            dev = parts[0]
                            if dev.startswith("/dev/"):
                                base = re.sub(
                                    r"p?[0-9]*$", "", dev.replace("/dev/", "")
                                )
                                rota_path = f"/sys/block/{base}/queue/rotational"
                                if os.path.exists(rota_path):
                                    with open(rota_path, "r") as f2:
                                        types[mount] = (
                                            "hdd" if f2.read().strip() == "1" else "ssd"
                                        )
                            break
            except:
                pass
        return types

    def get_cpu(self):
        try:
            with open("/proc/stat", "r") as f:
                line = f.readline()
                if not line.startswith("cpu "):
                    return 0.0
                values = [int(x) for x in line.split()[1:]]
                idle = values[3] + values[4]
                total = sum(values)
                diff_idle = idle - self.prev_cpu_idle
                diff_total = total - self.prev_cpu_total
                self.prev_cpu_total = total
                self.prev_cpu_idle = idle
                if diff_total == 0:
                    return 0.0
                return max(
                    0.0, min(100.0, ((diff_total - diff_idle) * 100.0) / diff_total)
                )
        except:
            return 0.0

    def get_cpu_temp(self):
        base = "/sys/class/hwmon"
        if not os.path.exists(base):
            return -1
        for hwmon in os.listdir(base):
            path = os.path.join(base, hwmon)
            try:
                with open(os.path.join(path, "name"), "r") as f:
                    name = f.read().strip()
                if name in [
                    "coretemp",
                    "k10temp",
                    "zenpower",
                    "cpu_thermal",
                    "x86_pkg_temp",
                    "amd_energy",
                ]:
                    for item in os.listdir(path):
                        if item.endswith("_input") and item.startswith("temp"):
                            with open(os.path.join(path, item), "r") as f:
                                val = int(f.read().strip())
                                if 10000 < val < 120000:
                                    return val // 1000
            except:
                continue
        return -1

    def get_cpu_frequency(self):
        frequencies = []
        cpu_base = "/sys/devices/system/cpu"
        try:
            for cpu in os.listdir(cpu_base):
                if not re.fullmatch(r"cpu\d+", cpu):
                    continue
                path = os.path.join(cpu_base, cpu, "cpufreq", "scaling_cur_freq")
                try:
                    with open(path, "r") as f:
                        frequencies.append(float(f.read().strip()) / 1000.0)
                except (OSError, ValueError):
                    continue
        except OSError:
            pass

        if frequencies:
            return sum(frequencies) / len(frequencies)

        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if line.startswith("cpu MHz"):
                        frequencies.append(float(line.split(":", 1)[1].strip()))
        except (OSError, ValueError):
            pass
        return sum(frequencies) / len(frequencies) if frequencies else 0.0

    def get_mem(self):
        try:
            mem_total = 0
            mem_available = 0
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        mem_total = int(line.split()[1])
                    elif line.startswith("MemAvailable:"):
                        mem_available = int(line.split()[1])
                    if mem_total > 0 and mem_available > 0:
                        break
            if mem_total == 0:
                return 0.0, 0, 0, 0
            mem_used = mem_total - mem_available
            return (mem_used * 100.0) / mem_total, mem_total, mem_used, mem_available
        except:
            return 0.0, 0, 0, 0

    def get_disk_usage(self, disks):
        usage_map = {}
        used_map = {}
        total_map = {}
        for mount in disks:
            try:
                st = os.statvfs(mount)
                total = st.f_blocks * st.f_frsize
                used = total - (st.f_bavail * st.f_frsize)
                used_map[mount] = used
                total_map[mount] = total
                if total > 0:
                    usage_map[mount] = (used / total) * 100.0
                else:
                    usage_map[mount] = 0.0
            except:
                usage_map[mount] = 0.0
                used_map[mount] = 0
                total_map[mount] = 0
        return usage_map, used_map, total_map

    def _get_default_network_interfaces(self):
        interfaces = set()
        try:
            with open("/proc/net/route", "r") as f:
                next(f, None)
                for line in f:
                    fields = line.split()
                    if len(fields) > 3 and fields[1] == "00000000":
                        interfaces.add(fields[0])
        except OSError:
            pass

        if interfaces:
            return interfaces

        try:
            for interface in os.listdir("/sys/class/net"):
                if interface == "lo":
                    continue
                try:
                    with open(f"/sys/class/net/{interface}/operstate", "r") as f:
                        if f.read().strip() == "up":
                            interfaces.add(interface)
                except OSError:
                    continue
        except OSError:
            pass
        return interfaces

    def get_network_speed(self):
        interfaces = self._get_default_network_interfaces()
        rx_bytes = 0
        tx_bytes = 0

        try:
            with open("/proc/net/dev", "r") as f:
                for line in f:
                    if ":" not in line:
                        continue
                    name, values = line.split(":", 1)
                    if name.strip() not in interfaces:
                        continue
                    fields = values.split()
                    rx_bytes += int(fields[0])
                    tx_bytes += int(fields[8])
        except (OSError, ValueError, IndexError):
            return 0.0, 0.0

        now = time.monotonic()
        if self.prev_network_time is None:
            download = 0.0
            upload = 0.0
        else:
            elapsed = max(0.001, now - self.prev_network_time)
            download = max(0.0, (rx_bytes - self.prev_network_rx) / elapsed)
            upload = max(0.0, (tx_bytes - self.prev_network_tx) / elapsed)

        self.prev_network_rx = rx_bytes
        self.prev_network_tx = tx_bytes
        self.prev_network_time = now
        return download, upload

    def get_gpu_stats(self):
        usages = []
        temps = []
        drivers = []
        vram_used = []
        vram_total = []
        clock_mhz = []
        for gpu in self.gpu_info:
            u, t = 0.0, -1
            memory_used, memory_total, frequency = 0, 0, 0.0
            driver = self._get_pci_driver(gpu["pci_id"])
            drivers.append(driver)

            if gpu["vendor"] == "nvidia" and driver == "nvidia":
                is_active = True
                power_path = f"/sys/bus/pci/devices/{gpu['pci_id']}/power/runtime_status"
                if os.path.exists(power_path):
                    try:
                        with open(power_path, "r") as f:
                            is_active = f.read().strip() == "active"
                    except:
                        pass

                if is_active:
                    try:
                        out = (
                            subprocess.check_output(
                                [
                                    "nvidia-smi",
                                    "-i",
                                    gpu["pci_id"],
                                    "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.current.graphics",
                                    "--format=csv,noheader,nounits",
                                ]
                            )
                            .decode("utf-8")
                            .strip()
                        )
                        parts = out.split(",")
                        if len(parts) >= 5:
                            u, t = float(parts[0]), int(parts[1])
                            memory_used = int(float(parts[2])) * 1024 * 1024
                            memory_total = int(float(parts[3])) * 1024 * 1024
                            frequency = float(parts[4])
                    except:
                        pass
                else:
                    u, t = 0.0, -1
            elif gpu["vendor"] == "amd" and driver == "amdgpu":
                card = gpu["card"]
                try:
                    with open(
                        f"/sys/class/drm/{card}/device/gpu_busy_percent", "r"
                    ) as f:
                        u = float(f.read().strip())
                except:
                    pass
                try:
                    hwmon_base = f"/sys/class/drm/{card}/device/hwmon"
                    if os.path.exists(hwmon_base):
                        hwmon_dir = os.listdir(hwmon_base)[0]
                        with open(
                            os.path.join(hwmon_base, hwmon_dir, "temp1_input"), "r"
                        ) as f:
                            t = int(f.read().strip()) // 1000
                except:
                    pass
                try:
                    with open(
                        f"/sys/class/drm/{card}/device/mem_info_vram_used", "r"
                    ) as f:
                        memory_used = int(f.read().strip())
                    with open(
                        f"/sys/class/drm/{card}/device/mem_info_vram_total", "r"
                    ) as f:
                        memory_total = int(f.read().strip())
                except (OSError, ValueError):
                    pass
                try:
                    with open(
                        f"/sys/class/drm/{card}/device/pp_dpm_sclk", "r"
                    ) as f:
                        clock_data = f.read()
                    active_clock = next(
                        (line for line in clock_data.splitlines() if "*" in line),
                        "",
                    )
                    match = re.search(r"(\d+)\s*Mhz", active_clock, re.I)
                    if match:
                        frequency = float(match.group(1))
                except OSError:
                    pass
            elif gpu["vendor"] == "intel" and driver in ("i915", "xe"):
                card = gpu["card"]
                frequency_paths = [
                    f"/sys/class/drm/{card}/gt/gt0/rps_cur_freq_mhz",
                    f"/sys/class/drm/{card}/device/tile0/gt0/freq0/cur_freq",
                ]
                for path in frequency_paths:
                    try:
                        with open(path, "r") as f:
                            frequency = float(f.read().strip())
                        break
                    except (OSError, ValueError):
                        continue
            usages.append(u)
            temps.append(t)
            vram_used.append(memory_used)
            vram_total.append(memory_total)
            clock_mhz.append(frequency)
        return usages, temps, drivers, vram_used, vram_total, clock_mhz


if __name__ == "__main__":
    # Syntax: system_monitor.py [interval_ms] [disk1] [disk2] ...
    interval_ms = 2000
    disks = ["/"]

    if len(sys.argv) > 1:
        try:
            interval_ms = int(sys.argv[1])
            disks = sys.argv[2:] if len(sys.argv) > 2 else ["/"]
        except ValueError:
            disks = sys.argv[1:]

    monitor = SystemMonitor(disks)
    interval_sec = max(0.1, interval_ms / 1000.0)

    print(
        json.dumps(
            {
                "static": {
                    "cpu_model": monitor.cpu_model,
                    "gpu_names": [g["name"] for g in monitor.gpu_info],
                    "gpu_vendors": [g["vendor"] for g in monitor.gpu_info],
                    "gpu_drivers": [
                        monitor._get_pci_driver(g["pci_id"])
                        for g in monitor.gpu_info
                    ],
                    "disk_types": monitor.disk_types,
                    "gpu_count": len(monitor.gpu_info),
                }
            }
        ),
        flush=True,
    )

    try:
        while True:
            cpu_usage = monitor.get_cpu()
            cpu_temp = monitor.get_cpu_temp()
            cpu_frequency = monitor.get_cpu_frequency()
            ram_usage, ram_total, ram_used, ram_avail = monitor.get_mem()
            disk_usage, disk_used, disk_total = monitor.get_disk_usage(disks)
            network_download, network_upload = monitor.get_network_speed()
            (
                gpu_usages,
                gpu_temps,
                gpu_drivers,
                gpu_vram_used,
                gpu_vram_total,
                gpu_clock_mhz,
            ) = monitor.get_gpu_stats()

            print(
                json.dumps(
                    {
                        "cpu": {
                            "usage": cpu_usage,
                            "temp": cpu_temp,
                            "frequency": cpu_frequency,
                        },
                        "ram": {
                            "usage": ram_usage,
                            "total": ram_total,
                            "used": ram_used,
                            "available": ram_avail,
                        },
                        "disk": {
                            "usage": disk_usage,
                            "used": disk_used,
                            "total": disk_total,
                        },
                        "network": {
                            "download": network_download,
                            "upload": network_upload,
                        },
                        "gpu": {
                            "detected": len(monitor.gpu_info) > 0,
                            "count": len(monitor.gpu_info),
                            "usages": gpu_usages,
                            "temps": gpu_temps,
                            "drivers": gpu_drivers,
                            "vram_used": gpu_vram_used,
                            "vram_total": gpu_vram_total,
                            "clock_mhz": gpu_clock_mhz,
                        },
                    }
                ),
                flush=True,
            )
            time.sleep(interval_sec)
    except KeyboardInterrupt:
        sys.exit(0)
