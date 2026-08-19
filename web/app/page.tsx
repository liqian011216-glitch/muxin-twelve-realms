"use client";

import { useState } from "react";
import { FRAME_SCREENS, getTargetIndex } from "./frame-flow";

type OpeningChoice = "untrained" | "restrained" | "free" | null;

export default function Home() {
  const [screenIndex, setScreenIndex] = useState(0);
  const [openingChoice, setOpeningChoice] = useState<OpeningChoice>(null);
  const [loadedImage, setLoadedImage] = useState<string | null>(FRAME_SCREENS[0].image);
  const screen = FRAME_SCREENS[screenIndex];
  const imageLoaded = loadedImage === screen.image;

  const activate = (hotspotId: string, choice?: Exclude<OpeningChoice, null>) => {
    if (choice) setOpeningChoice(choice);
    setLoadedImage(null);
    setScreenIndex(getTargetIndex(screenIndex, hotspotId));
  };

  return (
    <main className="figma-stage" data-screen-index={screenIndex} data-opening-choice={openingChoice ?? ""}>
      <section
        className="figma-canvas"
        aria-label={`${screen.alt}，第 ${screenIndex + 1} 页，共 ${FRAME_SCREENS.length} 页`}
        aria-busy={!imageLoaded}
      >
        <img
          key={screen.image}
          className="figma-frame-image"
          src={screen.image}
          alt={screen.alt}
          draggable={false}
          data-loaded={imageLoaded}
          onLoad={() => setLoadedImage(screen.image)}
        />
        {imageLoaded && screen.hotspots.map((hotspot) => (
          <button
            key={hotspot.id}
            type="button"
            className="figma-hotspot"
            aria-label={hotspot.label}
            onClick={() => activate(hotspot.id, hotspot.choice)}
            style={{
              left: `${hotspot.rect.left}%`,
              top: `${hotspot.rect.top}%`,
              width: `${hotspot.rect.width}%`,
              height: `${hotspot.rect.height}%`,
            }}
          />
        ))}
      </section>
    </main>
  );
}
