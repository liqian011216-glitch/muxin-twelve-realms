import type { Metadata } from "next";
import "./globals.css";

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

export const metadata: Metadata = {
  title: "牧牛十二境 · 数字文化体验",
  description: "循大足石刻牧牛图的 16 幅画面，观照心念变化，步入牧心十二境的沉浸叙事。",
  icons: { icon: `${BASE_PATH}/favicon.svg` },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
