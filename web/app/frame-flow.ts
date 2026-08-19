export const FRAME_WIDTH = 1066;
export const FRAME_HEIGHT = 600;
const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

export type FrameRect = { left: number; top: number; width: number; height: number };
export type FrameHotspot = {
  id: string;
  label: string;
  rect: FrameRect;
  targetIndex: number;
  choice?: "untrained" | "restrained" | "free";
};
export type FrameScreen = {
  index: number;
  nodeId: string;
  image: string;
  alt: string;
  hotspots: readonly FrameHotspot[];
};

const whole: FrameRect = { left: 0, top: 0, width: 100, height: 100 };
const previous: FrameRect = { left: 88.2, top: 86.8, width: 4.2, height: 9.2 };
const next: FrameRect = { left: 92.5, top: 86.8, width: 4.2, height: 9.2 };
const realmPreviewRects: Partial<Record<number, { previous?: FrameRect; next?: FrameRect }>> = {
  4: { next: { left: 71.3, top: 13.3, width: 28.7, height: 56 } },
  5: { previous: { left: 0, top: 13.3, width: 30, height: 56 }, next: { left: 70.3, top: 13.3, width: 24.2, height: 56 } },
  6: { previous: { left: 2.6, top: 13.3, width: 32.6, height: 56 }, next: { left: 65.9, top: 13.3, width: 28.6, height: 56 } },
  7: { previous: { left: 0, top: 13.3, width: 31.6, height: 56 }, next: { left: 67.4, top: 13.3, width: 32.6, height: 56 } },
  8: { previous: { left: 0, top: 13.3, width: 22.6, height: 56 }, next: { left: 83, top: 13.3, width: 17, height: 56 } },
  9: { previous: { left: 0, top: 13.3, width: 31.3, height: 56 }, next: { left: 69.3, top: 13.3, width: 30.7, height: 56 } },
  10: { previous: { left: 0, top: 13.3, width: 24.9, height: 56 }, next: { left: 77.1, top: 13.3, width: 22.9, height: 56 } },
  11: { previous: { left: 0, top: 13.3, width: 26.5, height: 56 }, next: { left: 74.9, top: 13.3, width: 25.1, height: 56 } },
  12: { previous: { left: 0, top: 13.3, width: 15.4, height: 56 }, next: { left: 85.7, top: 13.3, width: 14.3, height: 56 } },
  13: { previous: { left: 0, top: 13.3, width: 35.2, height: 56 }, next: { left: 64.5, top: 13.3, width: 23.3, height: 56 } },
  14: { previous: { left: 0, top: 13.3, width: 36.2, height: 56 } },
};

const nodeIds = [
  "2:2", "3:36", "3:41", "3:64", "4:165", "7:217", "13:20", "29:58",
  "15:40", "29:76", "29:94", "29:130", "29:112", "29:148", "29:166", "29:304",
] as const;
const names = [
  "cover", "intro", "choice", "stone-intro", "untrained", "first-taming", "restrained", "turning-back",
  "tamed", "unforced", "forgotten", "solitary", "both-gone", "meditation", "mind-moon", "summary",
] as const;
const labels = [
  "牧牛十二境封面", "你所见之牛亦是你所观之心", "问心选择", "千年前有人将这份心境刻于石上",
  "未牧", "初调", "受制", "回首", "驯服", "任运", "相忘", "独照", "双泯", "禅定", "心月图", "一轮心月映照牧心十二境",
] as const;

function realmHotspots(index: number): readonly FrameHotspot[] {
  const previews = realmPreviewRects[index] ?? {};
  return [
    ...(previews.previous
      ? [{ id: "preview-previous", label: "点击左侧预览，进入上一境", rect: previews.previous, targetIndex: index - 1 }]
      : []),
    ...(previews.next
      ? [{ id: "preview-next", label: "点击右侧预览，进入下一境", rect: previews.next, targetIndex: index + 1 }]
      : []),
    { id: "previous", label: "上一境", rect: previous, targetIndex: index - 1 },
    { id: "next", label: index === 14 ? "开启牧心十二境总结" : "下一境", rect: next, targetIndex: index + 1 },
  ];
}

export const FRAME_SCREENS: readonly FrameScreen[] = names.map((name, index) => ({
  index,
  nodeId: nodeIds[index],
  image: `${BASE_PATH}/frames/${String(index).padStart(2, "0")}-${name}.png`,
  alt: labels[index],
  hotspots: index === 0
    ? [{ id: "start", label: "问心，开始旅程", rect: { left: 17.5, top: 70, width: 21, height: 12 }, targetIndex: 1 }]
    : index === 1
      ? [{ id: "continue", label: "继续问心", rect: whole, targetIndex: 2 }]
      : index === 2
        ? [
            { id: "untrained", label: "选择未牧之牛", rect: { left: 9.5, top: 31, width: 25, height: 57 }, targetIndex: 3, choice: "untrained" },
            { id: "restrained", label: "选择受制之牛", rect: { left: 37.5, top: 31, width: 25, height: 57 }, targetIndex: 3, choice: "restrained" },
            { id: "free", label: "选择自在之牛", rect: { left: 65, top: 31, width: 25, height: 57 }, targetIndex: 3, choice: "free" },
          ]
        : index === 3
          ? [{ id: "enter", label: "循迹入境", rect: whole, targetIndex: 4 }]
          : index >= 4 && index <= 14
            ? realmHotspots(index)
            : [],
}));

export function getTargetIndex(screenIndex: number, hotspotId: string): number {
  const hotspot = FRAME_SCREENS[screenIndex]?.hotspots.find((item) => item.id === hotspotId);
  if (!hotspot) throw new RangeError(`Unknown hotspot ${hotspotId} on screen ${screenIndex}`);
  return hotspot.targetIndex;
}
