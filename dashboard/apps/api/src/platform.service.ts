import { Injectable } from "@nestjs/common";
import { connect } from "node:net";
import { readdir, readFile, stat } from "node:fs/promises";
import { basename, join } from "node:path";

type BrokerRequest={action:string;target?:string;args?:string[];actor:string};
@Injectable() export class PlatformService {
  private projectsRoot=process.env.AIOPS_PROJECTS_ROOT ?? "/srv/projects";
  async telemetry(){try{const r=await fetch(`${process.env.AIOPS_TELEMETRY_URL??"http://127.0.0.1:9108"}/snapshot`,{signal:AbortSignal.timeout(1500)});if(r.ok)return await r.json();}catch{}return {host:"unavailable",uptime:"—",load:0,memory:0,managers:[]};}
  async projects(){
    const result:{name:string;status:string;services:number;health:string;updated:string}[]=[];
    try{for(const entry of await readdir(this.projectsRoot,{withFileTypes:true})){if(!entry.isDirectory())continue;const env=join(this.projectsRoot,entry.name,".aiops/project.env");try{const [content,meta]=await Promise.all([readFile(env,"utf8"),stat(env)]);const name=content.match(/^AIOPS_PROJECT_NAME=(.+)$/m)?.[1]??entry.name;result.push({name,status:"Isolated environment",services:1,health:"idle",updated:new Intl.DateTimeFormat("en",{month:"short",day:"numeric"}).format(meta.mtime)});}catch{}}}catch{}
    return result.sort((a,b)=>a.name.localeCompare(b.name));
  }
  broker(request:BrokerRequest):Promise<unknown>{return new Promise((resolve,reject)=>{const socket=connect(process.env.AIOPS_BROKER_SOCKET??"/run/aiops-dashboard/broker.sock");let data="";const timer=setTimeout(()=>{socket.destroy();reject(new Error("broker timeout"));},30_000);socket.on("connect",()=>socket.end(JSON.stringify(request)+"\n"));socket.on("data",c=>data+=c);socket.on("end",()=>{clearTimeout(timer);try{resolve(JSON.parse(data));}catch{reject(new Error("invalid broker response"));}});socket.on("error",e=>{clearTimeout(timer);reject(e);});});}
  safeProjectName(path:string){return basename(path);}
}
