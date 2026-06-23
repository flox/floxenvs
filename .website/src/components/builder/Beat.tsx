export default function Beat({ title, body }: { title: string; body: string }) {
  return (
    <aside class="hairline border-l-2 pl-4 py-2 my-4">
      <p class="accent text-sm uppercase tracking-wide">{title}</p>
      <p class="text-[var(--builder-muted)] text-sm leading-relaxed max-w-[60ch]">
        {body}
      </p>
    </aside>
  );
}
