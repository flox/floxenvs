#!/usr/bin/env bash

echo

# Confirm policy.json exits
if [ "$(uname -s)" = 'Linux' ] && [ ! -f ~/.config/containers/policy.json ]; then
    if gum confirm "Create containers/policy.json file?" --default=true --affirmative "Yes" --negative "No"; then
        mkdir -p ~/.config/containers/
        printf '%s\n' '{"default": [{"type": "insecureAcceptAnything"}]}' > ~/.config/containers/policy.json
        echo "✅ Podman policy created at ~/.config/containers/policy.json"
    fi
fi

# Ensure podman can run
if [ "$(uname -s)" = 'Linux' ] || [ "$(podman machine ssh -- uname -s 2>/dev/null)" = "Linux" ]; then
    echo "🍟 Podman is available."
    exit
fi

# We need a virtual machine
autostart="$HOME/.config/podman-env/autostart"
choice=
if [ ! -f "$autostart" ]; then
    echo "Would you like to create and start the Podman virtual machine?"
    choice=$(gum choose "Always - start now & on future activations" "Yes - start now only" "No - do not start")
    if [ "${choice:0:1}" = "A" ]; then
        mkdir -p "$HOME"/.config/podman-env
        echo "1" > "$autostart"
        echo
        echo "Machine will start automatically on next activation. To disable this, run:"
        echo "  rm $autostart"
    fi
fi

if [ -f "$autostart" ] || [ "${choice:0:1}" = "A" ] || [ "${choice:0:1}" = "Y" ] ; then
    gum spin --spinner dot --title "Initializing machine..." -- podman machine init || true
    gum spin --spinner dot --title "Starting machine..." -- podman machine start
    if [ "$(podman machine ssh -- uname -s 2>/dev/null)" = "Linux" ]; then
        echo "✅ Podman virtual machine started - stop it with 'podman machine stop' or exit this shell."
        exit
    fi
fi

echo "🚨 Podman is not available."
