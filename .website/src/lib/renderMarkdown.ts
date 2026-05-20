import { createMarkdownProcessor } from "@astrojs/markdown-remark";

let processorPromise: ReturnType<typeof createMarkdownProcessor> | null = null;

function getProcessor() {
  if (!processorPromise) {
    processorPromise = createMarkdownProcessor({
      gfm: true,
      smartypants: true,
      syntaxHighlight: "shiki",
      shikiConfig: { theme: "github-dark-dimmed" },
    });
  }
  return processorPromise;
}

export async function renderMarkdown(md: string): Promise<string> {
  if (!md) return "";
  const processor = await getProcessor();
  const result = await processor.render(md);
  return result.code;
}
