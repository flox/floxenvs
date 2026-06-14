"""Honcho self-host quickstart.

Run against the local Honcho server (the honcho-api service):

    flox activate --start-services
    export LLM_OPENAI_API_KEY=sk-...   # optional, enables peer.chat

For local inference (LM Studio / vLLM / OpenRouter), set a base URL
instead of a real key, e.g.:

    export LLM_OPENAI_BASE_URL=http://127.0.0.1:1234/v1
    export LLM_OPENAI_API_KEY=not-needed

    python quickstart.py

Mirrors the README's Store -> Reason -> Query -> Inject loop:
https://github.com/plastic-labs/honcho#quickstart
"""

from __future__ import annotations

import os
import sys

from honcho import Honcho

HONCHO_URL = os.environ.get("HONCHO_URL", "http://127.0.0.1:18000")
WORKSPACE = "honcho-demo"


def main() -> int:
    print(f">>> connecting to {HONCHO_URL}")
    honcho = Honcho(
        workspace_id=WORKSPACE,
        base_url=HONCHO_URL,
        api_key=os.environ.get("HONCHO_API_KEY", "local-dev"),
    )

    # 1. Store — two peers exchanging a few messages on a session.
    alice = honcho.peer("alice")
    tutor = honcho.peer("tutor")
    session = honcho.session("demo-session")
    session.add_messages(
        [
            alice.message("Hey there — can you help me with my math homework?"),
            tutor.message("Absolutely. Send me your first problem!"),
            alice.message(
                "I'm working on quadratic equations and I keep getting confused"
                " by the discriminant."
            ),
            tutor.message(
                "Let's start with what b²-4ac means geometrically. Walk me"
                " through your last attempt."
            ),
        ]
    )
    print(f">>> stored 4 messages on workspace={WORKSPACE!r} session=demo-session")

    # 2. Query — these only need the storage service (no LLM key).
    rep = alice.representation()
    print(f">>> alice.representation() returned: {type(rep).__name__}")

    # 3. Chat / context — these go through the dialectic + LLM path.
    if not any(
        os.environ.get(k)
        for k in ("LLM_OPENAI_API_KEY", "LLM_ANTHROPIC_API_KEY", "LLM_GEMINI_API_KEY")
    ):
        print(
            ">>> skipping peer.chat() and session.context() — no LLM_*_API_KEY"
            " set. Storage-side calls above already succeeded."
        )
        return 0

    try:
        answer = alice.chat("What is the user struggling with?")
        print(">>> alice.chat(): " + str(answer)[:200])

        ctx = session.context(summary=True, tokens=2000)
        msgs = ctx.to_openai(assistant=tutor)
        print(f">>> session.context().to_openai(): {len(msgs)} messages ready")
    except Exception as exc:  # noqa: BLE001 — demo, want the message
        print(f">>> reasoning call failed: {exc}")
        return 1

    print(">>> quickstart complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
