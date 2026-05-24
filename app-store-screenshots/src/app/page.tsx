"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { toPng } from "html-to-image";

/* ─── Constants ─────────────────────────────────────────────── */

const IPHONE_W = 1320;
const IPHONE_H = 2868;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

/* Mockup measurements */
const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

/* Design tokens */
const T = {
  bg: "#07080E",
  fg: "#F8FAFC",
  accent: "#FFD98D",
  muted: "#6B7280",
  sunGold: "radial-gradient(circle, #FFE8A0 0%, #FFCF57 50%, #D4A017 100%)",
  deepBlue: "#0B1228",
  violet: "#1A0E3A",
};

/* ─── Phone Mockup ──────────────────────────────────────────── */

function Phone({
  src,
  alt,
  style,
  className = "",
}: {
  src: string;
  alt: string;
  style?: React.CSSProperties;
  className?: string;
}) {
  return (
    <div
      className={`relative ${className}`}
      style={{ aspectRatio: `${MK_W}/${MK_H}`, ...style }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/mockup.png"
        alt=""
        className="block w-full h-full"
        draggable={false}
      />
      <div
        className="absolute z-10 overflow-hidden"
        style={{
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={src}
          alt={alt}
          className="block w-full h-full object-cover object-top"
          draggable={false}
        />
      </div>
    </div>
  );
}

/* ─── Caption ───────────────────────────────────────────────── */

function Caption({
  label,
  headline,
  canvasW = IPHONE_W,
  align = "center",
  color = T.fg,
}: {
  label?: string;
  headline: string;
  canvasW?: number;
  align?: "center" | "left";
  color?: string;
}) {
  return (
    <div
      style={{
        textAlign: align,
        padding: `0 ${canvasW * 0.06}px`,
        fontFamily: "var(--font-geist-mono), ui-monospace, monospace",
      }}
    >
      {label && (
        <div
          style={{
            fontSize: canvasW * 0.028,
            fontWeight: 600,
            color: T.accent,
            letterSpacing: "0.12em",
            textTransform: "uppercase",
            marginBottom: canvasW * 0.015,
          }}
        >
          {label}
        </div>
      )}
      <div
        style={{
          fontSize: canvasW * 0.082,
          fontWeight: 700,
          lineHeight: 1.0,
          color,
          letterSpacing: "-0.01em",
        }}
        dangerouslySetInnerHTML={{ __html: headline }}
      />
    </div>
  );
}

/* ─── Decorative star dots ──────────────────────────────────── */

function Stars({ count = 60, seed = 42 }: { count?: number; seed?: number }) {
  const stars = Array.from({ length: count }, (_, i) => {
    const x = ((seed * (i + 1) * 7919) % 10000) / 100;
    const y = ((seed * (i + 1) * 104729) % 10000) / 100;
    const size = 1 + ((seed * (i + 1) * 31) % 3);
    const opacity = 0.15 + ((seed * (i + 1) * 17) % 60) / 100;
    return { x, y, size, opacity };
  });

  return (
    <>
      {stars.map((s, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: `${s.x}%`,
            top: `${s.y}%`,
            width: s.size,
            height: s.size,
            borderRadius: "50%",
            background: "#fff",
            opacity: s.opacity,
            pointerEvents: "none",
          }}
        />
      ))}
    </>
  );
}

/* ─── Slide 1: Hero ─────────────────────────────────────────── */

function Slide1({ canvasW = IPHONE_W, canvasH = IPHONE_H }) {
  return (
    <div
      style={{
        width: canvasW,
        height: canvasH,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(170deg, ${T.deepBlue} 0%, ${T.bg} 40%, ${T.violet} 100%)`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        fontFamily: "var(--font-geist-mono), ui-monospace, monospace",
      }}
    >
      <Stars count={80} seed={42} />

      {/* Ambient glow */}
      <div
        style={{
          position: "absolute",
          top: "30%",
          left: "50%",
          transform: "translate(-50%, -50%)",
          width: canvasW * 0.9,
          height: canvasW * 0.9,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(255,217,141,0.08) 0%, transparent 70%)",
          pointerEvents: "none",
        }}
      />

      {/* App icon */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/screenshots/icon.png"
        alt="Starpath icon"
        draggable={false}
        style={{
          marginTop: canvasH * 0.08,
          width: canvasW * 0.15,
          height: canvasW * 0.15,
          borderRadius: canvasW * 0.033,
          boxShadow: "0 8px 40px rgba(255,217,141,0.3)",
          marginBottom: canvasW * 0.04,
        }}
      />

      <Caption
        label="Starpath"
        headline="The sky<br/>you can&apos;t see."
        canvasW={canvasW}
      />

      {/* Phone */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(12%)",
          width: "84%",
        }}
      >
        <Phone src="/screenshots/app.png" alt="Starpath main chart" />
      </div>
    </div>
  );
}

/* ─── Slide 2: Widget ───────────────────────────────────────── */

function Slide2({ canvasW = IPHONE_W, canvasH = IPHONE_H }) {
  return (
    <div
      style={{
        width: canvasW,
        height: canvasH,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(180deg, #0D1326 0%, ${T.bg} 50%, #0F0A20 100%)`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        fontFamily: "var(--font-geist-mono), ui-monospace, monospace",
      }}
    >
      <Stars count={70} seed={101} />

      {/* Top caption */}
      <div style={{ marginTop: canvasH * 0.08 }}>
        <Caption
          label="Widgets"
          headline="Always there.<br/>Quietly changing."
          canvasW={canvasW}
        />
      </div>

      {/* Widget screenshot in phone */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(12%)",
          width: "84%",
        }}
      >
        <Phone
          src="/screenshots/widget.png"
          alt="Starpath widget on Home Screen"
        />
      </div>
    </div>
  );
}

/* ─── Slide 3: Geocentric Wheel ─────────────────────────────── */

function Slide3({ canvasW = IPHONE_W, canvasH = IPHONE_H }) {
  return (
    <div
      style={{
        width: canvasW,
        height: canvasH,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(170deg, #0A0F22 0%, ${T.bg} 45%, #0E0820 100%)`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        fontFamily: "var(--font-geist-mono), ui-monospace, monospace",
      }}
    >
      <Stars count={65} seed={314} />

      {/* Subtle orbital glow */}
      <div
        style={{
          position: "absolute",
          bottom: "30%",
          left: "50%",
          transform: "translateX(-50%)",
          width: canvasW * 0.7,
          height: canvasW * 0.7,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(100,180,255,0.04) 0%, transparent 70%)",
          pointerEvents: "none",
        }}
      />

      <div style={{ marginTop: canvasH * 0.08 }}>
        <Caption
          label="Three views"
          headline="Same sky.<br/>New perspective."
          canvasW={canvasW}
        />
      </div>

      {/* Phone — centered */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(12%)",
          width: "84%",
        }}
      >
        <Phone src="/screenshots/wheel.png" alt="Geocentric wheel view" />
      </div>
    </div>
  );
}

/* ─── Slide 4: Planet Details ───────────────────────────────── */

function Slide4({ canvasW = IPHONE_W, canvasH = IPHONE_H }) {
  return (
    <div
      style={{
        width: canvasW,
        height: canvasH,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(160deg, ${T.bg} 0%, #0C0E1D 40%, #1A0D30 100%)`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        fontFamily: "var(--font-geist-mono), ui-monospace, monospace",
      }}
    >
      <Stars count={55} seed={199} />

      {/* Gold glow from bottom */}
      <div
        style={{
          position: "absolute",
          bottom: "20%",
          left: "50%",
          transform: "translateX(-50%)",
          width: canvasW * 0.8,
          height: canvasW * 0.8,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(255,217,141,0.05) 0%, transparent 70%)",
          pointerEvents: "none",
        }}
      />

      <div style={{ marginTop: canvasH * 0.08 }}>
        <Caption
          label="Tap any planet"
          headline="The data<br/>behind the symbol."
          canvasW={canvasW}
        />
      </div>

      {/* Phone — centered */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(14%)",
          width: "84%",
        }}
      >
        <Phone src="/screenshots/detail.png" alt="Planet detail overlay" />
      </div>
    </div>
  );
}

/* ─── Slide Registry ────────────────────────────────────────── */

const IPHONE_SLIDES = [
  { id: "hero", label: "Hero", Component: Slide1 },
  { id: "widget", label: "Widget", Component: Slide2 },
  { id: "wheel", label: "Wheel", Component: Slide3 },
  { id: "details", label: "Details", Component: Slide4 },
];

/* ─── Screenshot Preview (scaled) ───────────────────────────── */

function ScreenshotPreview({
  slide,
  index,
  selectedSize,
  onExport,
}: {
  slide: (typeof IPHONE_SLIDES)[number];
  index: number;
  selectedSize: (typeof IPHONE_SIZES)[number];
  onExport: (el: HTMLDivElement, name: string, w: number, h: number) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);

  useEffect(() => {
    if (!containerRef.current) return;
    const ro = new ResizeObserver((entries) => {
      const { width } = entries[0].contentRect;
      setScale(width / IPHONE_W);
    });
    ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, []);

  const { Component } = slide;

  return (
    <div className="flex flex-col gap-2">
      {/* Preview */}
      <div
        ref={containerRef}
        className="relative overflow-hidden rounded-lg border border-white/10"
        style={{
          aspectRatio: `${IPHONE_W}/${IPHONE_H}`,
          background: T.bg,
        }}
      >
        <div
          style={{
            transform: `scale(${scale})`,
            transformOrigin: "top left",
            width: IPHONE_W,
            height: IPHONE_H,
          }}
        >
          <Component canvasW={IPHONE_W} canvasH={IPHONE_H} />
        </div>
      </div>

      {/* Offscreen full-res for export */}
      <div
        ref={canvasRef}
        data-offscreen
        style={{
          position: "absolute",
          left: -9999,
          top: 0,
          width: selectedSize.w,
          height: selectedSize.h,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            transform: `scale(${selectedSize.w / IPHONE_W})`,
            transformOrigin: "top left",
            width: IPHONE_W,
            height: IPHONE_H,
          }}
        >
          <Component canvasW={IPHONE_W} canvasH={IPHONE_H} />
        </div>
      </div>

      <div className="flex items-center justify-between">
        <span className="text-sm text-white/60 font-mono">
          {String(index + 1).padStart(2, "0")} — {slide.label}
        </span>
        <button
          onClick={() => {
            if (canvasRef.current) {
              onExport(
                canvasRef.current,
                `${String(index + 1).padStart(2, "0")}-${slide.id}`,
                selectedSize.w,
                selectedSize.h
              );
            }
          }}
          className="text-xs px-3 py-1 rounded bg-white/10 hover:bg-white/20 transition-colors font-mono"
        >
          Export
        </button>
      </div>
    </div>
  );
}

/* ─── Main Page ─────────────────────────────────────────────── */

export default function ScreenshotsPage() {
  const [sizeIdx, setSizeIdx] = useState(0);
  const [exporting, setExporting] = useState(false);

  const selectedSize = IPHONE_SIZES[sizeIdx];

  const handleExport = useCallback(
    async (el: HTMLDivElement, name: string, w: number, h: number) => {
      setExporting(true);
      try {
        el.style.left = "0px";
        el.style.opacity = "1";
        el.style.zIndex = "-1";

        const opts = { width: w, height: h, pixelRatio: 1, cacheBust: true };

        // Double-call trick: first warms fonts/images
        await toPng(el, opts);
        const dataUrl = await toPng(el, opts);

        el.style.left = "-9999px";
        el.style.opacity = "";
        el.style.zIndex = "";

        const link = document.createElement("a");
        link.download = `${name}-${w}x${h}.png`;
        link.href = dataUrl;
        link.click();
      } catch (err) {
        console.error("Export failed:", err);
      } finally {
        setExporting(false);
      }
    },
    []
  );

  const handleExportAll = useCallback(async () => {
    setExporting(true);
    const offscreens = document.querySelectorAll<HTMLDivElement>(
      "[data-offscreen]"
    );

    for (let i = 0; i < offscreens.length; i++) {
      const el = offscreens[i];
      const slide = IPHONE_SLIDES[i];
      const name = `${String(i + 1).padStart(2, "0")}-${slide.id}`;

      el.style.left = "0px";
      el.style.opacity = "1";
      el.style.zIndex = "-1";

      const opts = {
        width: selectedSize.w,
        height: selectedSize.h,
        pixelRatio: 1,
        cacheBust: true,
      };

      try {
        await toPng(el, opts);
        const dataUrl = await toPng(el, opts);

        const link = document.createElement("a");
        link.download = `${name}-${selectedSize.w}x${selectedSize.h}.png`;
        link.href = dataUrl;
        link.click();
      } catch (err) {
        console.error(`Export failed for slide ${i + 1}:`, err);
      }

      el.style.left = "-9999px";
      el.style.opacity = "";
      el.style.zIndex = "";

      if (i < offscreens.length - 1) {
        await new Promise((r) => setTimeout(r, 300));
      }
    }

    setExporting(false);
  }, [selectedSize]);

  return (
    <div className="min-h-screen bg-neutral-950 text-white font-mono">
      {/* Toolbar */}
      <div className="sticky top-0 z-50 backdrop-blur-xl bg-neutral-950/80 border-b border-white/10 px-6 py-3 flex items-center justify-between">
        <h1 className="text-sm font-semibold tracking-wider uppercase text-white/60">
          Starpath Screenshots
        </h1>

        <div className="flex items-center gap-4">
          <select
            value={sizeIdx}
            onChange={(e) => setSizeIdx(Number(e.target.value))}
            className="bg-white/10 text-sm rounded px-2 py-1 font-mono border border-white/10"
          >
            {IPHONE_SIZES.map((s, i) => (
              <option key={i} value={i}>
                {s.label} — {s.w}x{s.h}
              </option>
            ))}
          </select>

          <button
            onClick={handleExportAll}
            disabled={exporting}
            className="text-sm px-4 py-1.5 rounded bg-amber-500/20 text-amber-300 hover:bg-amber-500/30 transition-colors disabled:opacity-50 font-mono"
          >
            {exporting ? "Exporting..." : "Export All"}
          </button>
        </div>
      </div>

      {/* Screenshot Grid */}
      <div className="p-6 flex gap-6 overflow-x-auto max-w-full mx-auto [&>*]:min-w-[300px] [&>*]:flex-1">
        {IPHONE_SLIDES.map((slide, i) => (
          <ScreenshotPreview
            key={slide.id}
            slide={slide}
            index={i}
            selectedSize={selectedSize}
            onExport={handleExport}
          />
        ))}
      </div>
    </div>
  );
}
