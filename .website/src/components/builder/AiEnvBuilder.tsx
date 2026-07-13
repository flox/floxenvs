// .website/src/components/builder/AiEnvBuilder.tsx
import { useEffect, useMemo, useReducer, useState } from "preact/hooks";
import {
  STEPS,
  initialState,
  wizardReducer,
  type StepId,
} from "../../lib/wizardState";
import {
  decodeSelection,
  encodeSelection,
  type Selection,
} from "../../lib/selectionHash";
import {
  dataJsonToItems,
  partition,
  type RawDataJson,
  type WizardItem,
} from "../../lib/wizardItems";
import Beat from "./Beat";
import SelectionList from "./SelectionList";
import SelectionSummary from "./SelectionSummary";
import OutputPane from "./OutputPane";

const BEATS: Record<StepId, { title: string; body: string }> = {
  intro: {
    title: "When AI is the variable",
    body: "everything else must be the constant. Build an AI environment you can rebuild from scratch, pinned end to end.",
  },
  agent: {
    title: "The harness is half the story",
    body: "Same model, a 51-point spread across harnesses. A harness swap is roughly twice a model generation. Pick yours.",
  },
  skills: {
    title: "Same lever, both directions",
    body: "Curated skills lift results by 23 points. A bad one drops them by 10. About 26 percent of community skills carry a vulnerability. The score on the right is the real scan.",
  },
  tools: {
    title: "Skills are supply chain",
    body: "A clean audit is not clean code. Add the scanners that pin and check what your agent loads.",
  },
  output: {
    title: "Works on purpose, not by accident",
    body: "A skill without its own environment works by accident. Here is yours, locked to exact packages.",
  },
};

const DATA_URL = `${import.meta.env.BASE_URL}data.json`;

export default function AiEnvBuilder({ snapshot }: { snapshot?: RawDataJson }) {
  const seed = useMemo(
    () =>
      typeof window !== "undefined"
        ? decodeSelection(window.location.hash)
        : { agents: [], skills: [], tools: [] },
    [],
  );
  const [state, dispatch] = useReducer(wizardReducer, initialState(seed));
  const [raw, setRaw] = useState<RawDataJson | null>(snapshot ?? null);
  const [query, setQuery] = useState("");

  // Refresh from the live data.json; fall back to the bundled snapshot.
  useEffect(() => {
    let alive = true;
    fetch(DATA_URL)
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((d) => {
        if (alive) setRaw(d as RawDataJson);
      })
      .catch(() => {
        /* keep snapshot */
      });
    return () => {
      alive = false;
    };
  }, []);

  // Sync selection to the URL hash (this IS the share link).
  useEffect(() => {
    const hash = encodeSelection(state.selection);
    const url = `${window.location.pathname}${window.location.search}${hash}`;
    window.history.replaceState(null, "", url);
  }, [state.selection]);

  // Keyboard model: ArrowRight advances steps, ArrowLeft/Esc goes back,
  // "/" focuses search on the skills step. Tab is intentionally left alone
  // for native focus traversal and a11y.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") {
        if (e.key === "Escape") (e.target as HTMLElement).blur();
        return;
      }
      if (e.key === "ArrowRight") {
        e.preventDefault();
        dispatch({ type: "next" });
      } else if (e.key === "ArrowLeft" || e.key === "Escape") {
        dispatch({ type: "prev" });
      } else if (e.key === "/") {
        e.preventDefault();
        document.getElementById("builder-search")?.focus();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const items = useMemo(
    () => (raw ? dataJsonToItems(raw) : []),
    [raw],
  );
  const groups = useMemo(() => partition(items), [items]);
  const byId = useMemo(
    () => new Map(items.map((i) => [i.id, i])),
    [items],
  );
  const selectedItems: WizardItem[] = [
    ...state.selection.agents,
    ...state.selection.skills,
    ...state.selection.tools,
  ]
    .map((id) => byId.get(id))
    .filter((x): x is WizardItem => Boolean(x));

  const step = STEPS[state.stepIndex];
  const beat = BEATS[step];
  const toggle = (group: keyof Selection) => (id: string) =>
    dispatch({ type: "toggle", group, id });

  const filteredSkills = groups.skills.filter((s) =>
    s.name.toLowerCase().includes(query.toLowerCase()),
  );

  return (
    <section class="builder min-h-[100dvh] p-6 md:p-10">
      <header class="hairline border-b pb-3 flex items-center justify-between">
        <span class="accent">flox · build your AI environment</span>
        <nav class="flex gap-2 text-sm">
          {STEPS.map((s, i) => (
            <button
              key={s}
              type="button"
              onClick={() => dispatch({ type: "goto", stepIndex: i })}
              class={i === state.stepIndex ? "accent" : "text-[var(--builder-muted)]"}
            >
              {i + 1}.{s}
            </button>
          ))}
        </nav>
      </header>

      <Beat title={beat.title} body={beat.body} />

      <div class="mt-2 min-h-[40dvh]">
        {step === "intro" && (
          <button type="button" class="accent border hairline px-4 py-2"
            onClick={() => dispatch({ type: "next" })}>
            start →
          </button>
        )}
        {step === "agent" && (
          <SelectionList
            items={groups.agents}
            selectedIds={state.selection.agents}
            onToggle={toggle("agents")}
          />
        )}
        {step === "skills" && (
          <div>
            <input
              id="builder-search"
              type="search"
              value={query}
              placeholder="/ to search skills"
              onInput={(e) => setQuery((e.target as HTMLInputElement).value)}
              class="w-full hairline border bg-transparent px-3 py-2 mb-3"
            />
            <SelectionList
              items={filteredSkills}
              selectedIds={state.selection.skills}
              onToggle={toggle("skills")}
              showAudit
            />
          </div>
        )}
        {step === "tools" && (
          <SelectionList
            items={groups.tools}
            selectedIds={state.selection.tools}
            onToggle={toggle("tools")}
          />
        )}
        {step === "output" && <OutputPane items={selectedItems} />}
      </div>

      <SelectionSummary items={selectedItems} />

      <footer class="hairline border-t mt-4 pt-2 text-sm text-[var(--builder-muted)] flex justify-between">
        <span>← / esc back · → next · / search</span>
        <span class="flex gap-2">
          <button type="button" onClick={() => dispatch({ type: "prev" })}>back</button>
          <button type="button" class="accent" onClick={() => dispatch({ type: "next" })}>
            next →
          </button>
        </span>
      </footer>
    </section>
  );
}
