"use client";

import { useMemo, useState } from "react";
import { ArrowIcon, BoxIcon, GridIcon, LayersIcon, MoonIcon, PulseIcon, SearchIcon, ShieldIcon, SunIcon } from "./icons";

type Metric = { label: string; value: string; detail: string; tone?: "green" | "blue" | "amber" };
const groups = [
  { title: "Overview", items: [["Home", "/home", GridIcon], ["Usage", "/usage", PulseIcon], ["Activity / Logs", "/logs", LayersIcon]] },
  { title: "Developer", items: [["API Keys", "/api-keys", ShieldIcon], ["Playground", "/playground", BoxIcon], ["Models", "/models", GridIcon], ["Batches", "/batches", LayersIcon], ["Docs", "/docs", LayersIcon]] },
  { title: "Billing", items: [["Credits / Top Up", "/top-up", PulseIcon], ["Billing", "/billing", BoxIcon], ["Invoices", "/invoices", LayersIcon]] },
  { title: "Organization", items: [["Users & Teams", "/users", ShieldIcon], ["Projects", "/projects", BoxIcon], ["Security", "/security", ShieldIcon], ["Settings", "/settings", GridIcon]] }
] as const;

export function PlatformDashboard({ active = "Usage" }: { active?: string }) {
  const [dark, setDark] = useState(false), [notice, setNotice] = useState(true), [range, setRange] = useState("30d"), [exported, setExported] = useState(false);
  const metrics: Metric[] = useMemo(() => [
    { label: "Total cost", value: "$0.00", detail: "No charges in this period", tone: "green" },
    { label: "API requests", value: "0", detail: "Across all services", tone: "blue" },
    { label: "Input tokens", value: "0", detail: "Prompt tokens processed" },
    { label: "Output tokens", value: "0", detail: "Completion tokens generated" },
    { label: "Cached tokens", value: "0", detail: "No cache activity" },
    { label: "Average latency", value: "—", detail: "Waiting for activity" }
  ], []);
  function exportUsage() { setExported(true); window.setTimeout(() => setExported(false), 2200); }
  return <div className={dark ? "platform-root platform-dark" : "platform-root"}>
    <aside className="platform-sidebar">
      <a href="/" className="platform-brand"><span className="platform-mark">S</span><span><b>SIMHA Online</b><small>Platform</small></span></a>
      <button className="org-switch"><span className="org-avatar">S</span><span><b>Simha Online</b><small>Personal organization</small></span><span>⌄</span></button>
      <nav aria-label="Platform navigation">{groups.map(group => <div className="platform-nav-group" key={group.title}><span>{group.title}</span>{group.items.map(([label, href, Icon]) => <a className={active.toLowerCase() === label.toLowerCase() ? "platform-nav active" : "platform-nav"} href={href} key={label}><Icon/><span>{label}</span></a>)}</div>)}</nav>
      <div className="platform-sidebar-foot"><div className="platform-user"><span className="user-avatar">SO</span><span><b>Simha Operator</b><small>operator@simhaonline.ai</small></span></div><a href="/settings" aria-label="Open settings">•••</a></div>
    </aside>
    <main className="platform-main">
      <header className="platform-header"><button className="platform-mobile-brand" aria-label="Open navigation">SIMHA</button><label className="platform-search"><SearchIcon/><input aria-label="Search platform" placeholder="Search platform"/><kbd>⌘ K</kbd></label><div className="platform-header-actions"><span className="platform-live"><i/>All systems operational</span><button className="platform-icon-button" onClick={() => setDark(!dark)} aria-label="Toggle theme">{dark ? <SunIcon/> : <MoonIcon/>}</button><a className="platform-chat-link" href="/">Open Studio <ArrowIcon/></a></div></header>
      {active.toLowerCase() === "usage" ? <UsagePage range={range} setRange={setRange} notice={notice} setNotice={setNotice} metrics={metrics} exported={exported} exportUsage={exportUsage}/> : <PlatformPlaceholder active={active}/>} 
    </main>
  </div>;
}

function UsagePage({ range, setRange, notice, setNotice, metrics, exported, exportUsage }: { range: string; setRange: (v: string) => void; notice: boolean; setNotice: (v: boolean) => void; metrics: Metric[]; exported: boolean; exportUsage: () => void }) {
  return <div className="platform-content"><div className="platform-page-heading"><div><span className="platform-eyebrow">Analytics</span><h1>Usage</h1><p>All dates and times are shown in GMT+4. Data may be delayed by a few minutes.</p></div><div className="platform-heading-actions"><button className="platform-secondary">More <span>⌄</span></button><button className="platform-primary" onClick={exportUsage}>Export CSV <ArrowIcon/></button></div></div>
    {notice && <div className="platform-announcement"><span className="announcement-icon">✦</span><div><b>SIMHA V2 models are now available</b><p>Explore improved reasoning, image understanding, and faster output across the platform.</p></div><a href="/models">Explore models <ArrowIcon/></a><button onClick={() => setNotice(false)} aria-label="Dismiss announcement">×</button></div>}
    <section className="platform-balance-grid"><article className="balance-card balance-primary"><div className="balance-card-head"><span>Topped-up balance</span><span className="balance-icon">$</span></div><strong>$0.00 <small>USD</small></strong><div className="balance-foot"><span className="status-pill">● Balance alerts enabled</span><button onClick={() => window.alert("Top-up flow will open when billing is connected.")}>Top up</button></div></article><article className="balance-card"><div className="balance-card-head"><span>Total cost</span><span className="balance-icon muted">∑</span></div><strong>$0.00 <small>USD</small></strong><p>No usage recorded in the selected period</p><a href="/billing">View billing <ArrowIcon/></a></article><article className="balance-card"><div className="balance-card-head"><span>Monthly budget</span><span className="balance-icon muted">◷</span></div><strong>Not set</strong><p>Set a limit to protect your spend</p><a href="/settings">Configure limits <ArrowIcon/></a></article></section>
    <section className="platform-filter-bar"><label>Time<select value={range} onChange={e => setRange(e.target.value)}><option value="24h">Last 24 hours</option><option value="7d">Last 7 days</option><option value="30d">Last 30 days</option><option value="90d">Last 90 days</option></select></label><label>Project<select><option>All projects</option></select></label><label>API key<select><option>All API keys</option></select></label><label>Service<select><option>All services</option></select></label><button className="filter-reset">Reset</button></section>
    <div className="platform-filter-summary"><span>Showing usage for <b>{range === "30d" ? "the last 30 days" : `the last ${range}`}</b></span><span>{exported ? "Usage export prepared" : "UTC offset: GMT+4"}</span></div>
    <section className="platform-metrics-grid">{metrics.map(metric => <article className="usage-metric" key={metric.label}><div><span>{metric.label}</span><i className={metric.tone ?? ""}>{metric.tone === "green" ? "↗" : metric.tone === "blue" ? "⌁" : "—"}</i></div><strong>{metric.value}</strong><small>{metric.detail}</small></article>)}</section>
    <section className="platform-analysis-grid"><article className="platform-panel"><div className="platform-panel-heading"><div><span>Cost over time</span><h2>Usage activity</h2></div><button className="platform-secondary">30 days ⌄</button></div><div className="empty-chart"><div className="chart-grid"><i/><i/><i/><i/></div><span>No usage data for this period</span><small>Activity will appear here after your first request.</small></div></article><article className="platform-panel"><div className="platform-panel-heading"><div><span>Service breakdown</span><h2>By model & service</h2></div></div><div className="empty-breakdown"><span className="breakdown-ring">0%</span><div><p><i className="dot dot-blue"/>Text & Chat <b>$0.00</b></p><p><i className="dot dot-purple"/>Image, Video & Audio <b>$0.00</b></p><p><i className="dot dot-gray"/>Agents & Tools <b>$0.00</b></p></div></div></article></section>
    <section className="platform-panel usage-table-panel"><div className="platform-panel-heading"><div><span>Request history</span><h2>Recent usage</h2></div><a href="/logs">View logs <ArrowIcon/></a></div><div className="usage-empty"><span>▱</span><b>No requests yet</b><p>When your API keys or Studio sessions make requests, they will appear here.</p><a href="/playground">Try the API playground <ArrowIcon/></a></div></section>
  </div>;
}

function PlatformPlaceholder({ active }: { active: string }) { return <div className="platform-content platform-placeholder"><span className="platform-eyebrow">Platform management</span><h1>{active}</h1><p>This workspace is ready for {active.toLowerCase()} management. Connect the authenticated API to load live records, permissions, and actions.</p><div className="placeholder-grid"><article><span>01</span><h2>Secure by default</h2><p>Tenant-aware access, explicit permissions, audit trails, and confirmation before destructive actions.</p></article><article><span>02</span><h2>Designed for scale</h2><p>Pagination, filters, exports, and background jobs keep large organizations responsive.</p></article><article><span>03</span><h2>Connect your data</h2><p>Configure the platform API to replace this safe empty state with live resources.</p></article></div></div>; }
