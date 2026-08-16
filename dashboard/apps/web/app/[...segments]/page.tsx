import { PlatformDashboard } from "../ui/platform-dashboard";

export default async function PlatformRoute({ params }: { params: Promise<{ segments: string[] }> }) {
  const { segments } = await params;
  const active = segments[0]?.replace(/-/g, " ").replace(/\b\w/g, c => c.toUpperCase()) ?? "Usage";
  return <PlatformDashboard active={active === "Api Keys" ? "API Keys" : active} />;
}
