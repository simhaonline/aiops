import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "SIMHA AiOps",
  description: "Private infrastructure and AI operations control plane"
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en" suppressHydrationWarning><body>{children}</body></html>;
}
