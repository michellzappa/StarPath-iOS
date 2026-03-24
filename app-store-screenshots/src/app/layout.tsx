import type { Metadata } from "next";
import { Geist_Mono } from "next/font/google";
import "./globals.css";

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Starpath — App Store Screenshots",
  description: "Screenshot generator for Starpath iOS app",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geistMono.variable} h-full antialiased`}>
      <body className={`${geistMono.className} min-h-full flex flex-col bg-neutral-950 text-white`}>
        {children}
      </body>
    </html>
  );
}
