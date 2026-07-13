import type { Selection } from "./selectionHash";

export const STEPS = ["intro", "agent", "skills", "tools", "output"] as const;
export type StepId = (typeof STEPS)[number];

export interface WizardState {
  stepIndex: number;
  selection: Selection;
}

export type WizardAction =
  | { type: "next" }
  | { type: "prev" }
  | { type: "goto"; stepIndex: number }
  | { type: "toggle"; group: keyof Selection; id: string }
  | { type: "setSelection"; selection: Selection };

const clamp = (n: number) => Math.max(0, Math.min(STEPS.length - 1, n));

export function initialState(selection?: Selection): WizardState {
  return {
    stepIndex: 0,
    selection: selection ?? { agents: [], skills: [], tools: [] },
  };
}

export function wizardReducer(
  state: WizardState,
  action: WizardAction,
): WizardState {
  switch (action.type) {
    case "next":
      return { ...state, stepIndex: clamp(state.stepIndex + 1) };
    case "prev":
      return { ...state, stepIndex: clamp(state.stepIndex - 1) };
    case "goto":
      return { ...state, stepIndex: clamp(action.stepIndex) };
    case "toggle": {
      const cur = state.selection[action.group];
      const next = cur.includes(action.id)
        ? cur.filter((x) => x !== action.id)
        : [...cur, action.id];
      return {
        ...state,
        selection: { ...state.selection, [action.group]: next },
      };
    }
    case "setSelection":
      return { ...state, selection: action.selection };
    default:
      return state;
  }
}
