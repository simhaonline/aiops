import { PlatformDashboard } from "../ui/platform-dashboard";
import { DashboardShell } from "../ui/dashboard-shell";

const workspaceRoutes = new Set(["studio", "codebases", "knowledge", "media", "workflows", "registry", "projects", "operations"]);

export default async function PlatformRoute({ params }: { params: Promise<{ segments: string[] }> }) {
  const { segments } = await params;
  const route = segments[0]?.toLowerCase() ?? "";
  if (workspaceRoutes.has(route)) {
    const initialActive = route === "studio" ? "Studio" : route.replace(/-/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    return <DashboardShell initialActive={initialActive} />;
  }
  const active = segments[0]?.replace(/-/g, " ").replace(/\b\w/g, c => c.toUpperCase()) ?? "Usage";
  return <PlatformDashboard active={active === "Api Keys" ? "API Keys" : active} />;
}
