"use client";
import { useEffect, useState } from "react";
import { ArrowIcon, BoxIcon, GridIcon, LayersIcon, PulseIcon, SearchIcon, ShieldIcon } from "./icons";
import { ThemeToggle } from "./theme-toggle";

type Overview = { host: string; uptime: string; load: number; memory: number; managers: {name:string; state:string; detail:string}[]; projects: {name:string; status:string; services:number; health:string; updated:string}[] };
const fallback: Overview = {host:"aiops-primary",uptime:"—",load:0,memory:0,managers:[{name:"Nginx edge",state:"checking",detail:"TLS and proxy"},{name:"Project runtime",state:"checking",detail:"Docker Compose"},{name:"Collection plane",state:"checking",detail:"Scrapling workers"}],projects:[]};

const nav = [{label:"Overview",icon:GridIcon},{label:"Projects",icon:BoxIcon},{label:"Collections",icon:LayersIcon},{label:"Telemetry",icon:PulseIcon},{label:"Security",icon:ShieldIcon}];
export function DashboardShell(){
  const [overview,setOverview]=useState(fallback); const [active,setActive]=useState("Overview"); const [now,setNow]=useState("");
  useEffect(()=>{setNow(new Intl.DateTimeFormat(undefined,{weekday:"long",month:"long",day:"numeric"}).format(new Date())); fetch("/api/overview").then(r=>r.ok?r.json():Promise.reject()).then(setOverview).catch(()=>{});},[]);
  return <div className="shell">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark"><span/></span><div><b>SIMHA</b><small>AiOps control plane</small></div></div>
      <nav aria-label="Primary">{nav.map(({label,icon:NavIcon})=><button key={label} className={active===label?"nav-item active":"nav-item"} onClick={()=>setActive(label)}><NavIcon/><span>{label}</span>{label==="Security"&&<i>3</i>}</button>)}</nav>
      <div className="sidebar-foot"><div className="environment"><span className="status-dot"/><div><b>Production</b><small>{overview.host}</small></div></div><button className="profile" aria-label="Account menu">SO</button></div>
    </aside>
    <main>
      <header><div className="mobile-brand">SIMHA AiOps</div><label className="search"><SearchIcon/><input placeholder="Search projects, services, collections" aria-label="Search"/><kbd>⌘ K</kbd></label><div className="header-actions"><span className="live"><i/>Live</span><ThemeToggle/></div></header>
      <div className="content">
        <section className="welcome"><div><p>{now}</p><h1>Good operations start with clarity.</h1><span>Infrastructure, agents and collections—one controlled surface.</span></div><button className="primary">Run health check <ArrowIcon/></button></section>
        <section className="signal-grid">
          <article className="signal"><div className="signal-head"><span>Platform health</span><i className="health-icon"><PulseIcon/></i></div><strong>Operational</strong><p>All critical controls responding</p><div className="mini-bars">{[38,54,46,66,52,72,61,78,68,82,73,88].map((h,i)=><i key={i} style={{height:`${h}%`}}/>)}</div></article>
          <article className="signal"><div className="signal-head"><span>Host load</span><i className="neutral-icon"><BoxIcon/></i></div><strong>{overview.load.toFixed(2)}</strong><p>{overview.uptime} uptime</p><div className="meter"><i style={{width:`${Math.min(overview.load*20,100)}%`}}/></div></article>
          <article className="signal"><div className="signal-head"><span>Memory</span><i className="neutral-icon"><LayersIcon/></i></div><strong>{overview.memory}%</strong><p>Across managed workloads</p><div className="meter"><i style={{width:`${overview.memory}%`}}/></div></article>
          <article className="signal attention"><div className="signal-head"><span>Needs attention</span><i>3</i></div><strong>3 findings</strong><p>2 certificates · 1 backup</p><button>Review findings <ArrowIcon/></button></article>
        </section>
        <section className="columns">
          <article className="panel projects"><div className="panel-title"><div><h2>Projects</h2><p>Isolated development environments</p></div><button>View all</button></div>
            <div className="table-head"><span>Project</span><span>Services</span><span>Health</span><span>Updated</span></div>
            {(overview.projects.length?overview.projects:[{name:"No projects discovered",status:"Initialize under /srv/projects",services:0,health:"idle",updated:"—"}]).map(p=><div className="project-row" key={p.name}><div className="project-name"><i>{p.name.slice(0,2).toUpperCase()}</i><span><b>{p.name}</b><small>{p.status}</small></span></div><span>{p.services}</span><span className={`pill ${p.health}`}>{p.health}</span><span>{p.updated}</span></div>)}
          </article>
          <article className="panel services"><div className="panel-title"><div><h2>Control services</h2><p>Local management plane</p></div><span className="quiet">{overview.managers.length} checks</span></div>
            <div className="service-list">{overview.managers.map((m,i)=><div className="service" key={m.name}><span className={`service-glyph g${i%3}`}><PulseIcon/></span><div><b>{m.name}</b><small>{m.detail}</small></div><span className={`service-state ${m.state}`}><i/>{m.state}</span></div>)}</div>
          </article>
        </section>
        <section className="bottom-grid"><article className="panel activity"><div className="panel-title"><div><h2>Recent activity</h2><p>Immutable operational audit trail</p></div><button>Open audit log</button></div><div className="empty-activity"><ShieldIcon/><b>No mutations in this session</b><span>Approved actions will appear here with actor, target and outcome.</span></div></article><article className="principle"><span>Operating principle 01</span><blockquote>“The interface can make operations easier. It must never make unsafe operations invisible.”</blockquote><p>Every mutation stays explicit, scoped and auditable.</p></article></section>
      </div>
    </main>
  </div>;
}
