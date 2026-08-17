#!/usr/bin/env python3
"""Small dependency-free, loopback-only AiOps telemetry collector."""
from __future__ import annotations
import json, os, shutil, socket, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

VERSION="1.0.0"
MANAGERS=(
    ("Nginx edge","nginx-manager","TLS and proxy"),
    ("Project runtime","project-manager","Docker Compose"),
    ("Collection plane","collection-manager","Scrapling workers"),
    ("Manager suite","manager-suite","Release controls"),
)

def memory_percent(meminfo: str|None=None)->int:
    text=meminfo if meminfo is not None else Path("/proc/meminfo").read_text()
    values={line.split(":",1)[0]:int(line.split()[1]) for line in text.splitlines() if ":" in line}
    total=values.get("MemTotal",0); available=values.get("MemAvailable",values.get("MemFree",0))
    return round((total-available)*100/total) if total else 0

def uptime_text(seconds: float|None=None)->str:
    seconds=seconds if seconds is not None else float(Path("/proc/uptime").read_text().split()[0])
    days=int(seconds//86400); hours=int(seconds%86400//3600)
    return f"{days}d {hours}h" if days else f"{hours}h"

def snapshot()->dict:
    load=os.getloadavg()[0]
    return {"host":socket.gethostname(),"uptime":uptime_text(),"load":round(load,2),"memory":memory_percent(),"timestamp":int(time.time()),"managers":[{"name":label,"state":"ready" if shutil.which(command) else "missing","detail":detail} for label,command,detail in MANAGERS]}

def prometheus(data:dict)->str:
    return "\n".join(("# HELP aiops_host_load_1m Host one minute load average","# TYPE aiops_host_load_1m gauge",f"aiops_host_load_1m {data['load']}","# HELP aiops_memory_used_percent Host memory used percentage","# TYPE aiops_memory_used_percent gauge",f"aiops_memory_used_percent {data['memory']}",""))

class Handler(BaseHTTPRequestHandler):
    server_version="AiOpsTelemetry/"+VERSION
    def do_GET(self):
        data=snapshot()
        if self.path=="/snapshot": self.reply(200,"application/json",json.dumps(data,separators=(",",":")).encode())
        elif self.path=="/metrics": self.reply(200,"text/plain; version=0.0.4",prometheus(data).encode())
        elif self.path=="/health": self.reply(200,"application/json",b'{"status":"ok"}')
        else: self.reply(404,"application/json",b'{"error":"not found"}')
    def reply(self,status:int,kind:str,body:bytes):
        self.send_response(status);self.send_header("Content-Type",kind);self.send_header("Content-Length",str(len(body)));self.send_header("Cache-Control","no-store");self.end_headers();self.wfile.write(body)
    def log_message(self,format,*args): return

def main():
    host=os.environ.get("AIOPS_TELEMETRY_HOST","127.0.0.1");port=int(os.environ.get("AIOPS_TELEMETRY_PORT","11082"))
    if host not in ("127.0.0.1","::1"): raise SystemExit("telemetry must remain loopback-only")
    ThreadingHTTPServer((host,port),Handler).serve_forever()
if __name__=="__main__": main()
