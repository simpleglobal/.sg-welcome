export CARGO_HOME="$HOME/SimpleGlobal/.cargo"
export RUSTUP_HOME="$HOME/SimpleGlobal/.rustup"
if [ -f "$CARGO_HOME/env" ]; then
    . "$CARGO_HOME/env"
fi
