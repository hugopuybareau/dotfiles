export SSH_ENV="$HOME/.ssh/agent.env"

function start_agent {
    echo "Initializing new SSH agent..."
    /usr/bin/ssh-agent -s > "${SSH_ENV}"
    chmod 600 "${SSH_ENV}"
    source "${SSH_ENV}" > /dev/null
}

# Check if SSH agent is running
if [ -f "${SSH_ENV}" ]; then
    source "${SSH_ENV}" > /dev/null
    # Verify both that the process exists and the socket is usable
    if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null || ! ssh-add -l &>/dev/null; then
        rm -f "${SSH_ENV}"
        start_agent
    fi
else
    start_agent
fi

# Ensure keys are added
# On macOS, prefer Keychain-backed loading: `ssh-add --apple-use-keychain <key>`
# re-adds passphrase-protected keys without prompting (passphrase is stored in
# the Keychain once you've run it manually). Plain `ssh-add` can't load a
# passphrase-protected key non-interactively, which left the agent empty.
ssh-add -l &>/dev/null || ssh-add --apple-use-keychain ~/.ssh/id_ed25519 &>/dev/null
