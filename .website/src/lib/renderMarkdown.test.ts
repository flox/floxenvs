import { describe, expect, it } from "vitest";
import { renderMarkdown } from "./renderMarkdown";

describe("renderMarkdown", () => {
  it("renders headings", async () => {
    const html = await renderMarkdown("# Hello");
    expect(html).toContain("<h1");
    expect(html).toContain("Hello");
  });

  it("renders fenced code blocks with a language class", async () => {
    const html = await renderMarkdown(
      "```bash\nflox activate\n```",
    );
    expect(html).toMatch(/<pre[^>]*>/);
    expect(html).toContain("flox");
    expect(html).toContain("activate");
  });

  it("renders GFM tables", async () => {
    const html = await renderMarkdown(
      "| a | b |\n| - | - |\n| 1 | 2 |",
    );
    expect(html).toContain("<table");
    expect(html).toContain("<th");
  });

  it("returns an empty string for empty input", async () => {
    expect(await renderMarkdown("")).toBe("");
  });
});
