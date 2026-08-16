"use client";
import { useEffect, useState } from "react";
import { MoonIcon, SunIcon } from "./icons";

export function ThemeToggle() {
  const [dark, setDark] = useState(false);
  useEffect(() => {
    const saved = localStorage.getItem("aiops-theme");
    const value = saved ? saved === "dark" : matchMedia("(prefers-color-scheme: dark)").matches;
    setDark(value); document.documentElement.dataset.theme = value ? "dark" : "light";
  }, []);
  const toggle = () => { const value=!dark; setDark(value); document.documentElement.dataset.theme=value?"dark":"light"; localStorage.setItem("aiops-theme",value?"dark":"light"); };
  return <button className="icon-button" onClick={toggle} aria-label={`Use ${dark ? "light" : "dark"} theme`}>{dark ? <SunIcon/> : <MoonIcon/>}</button>;
}
