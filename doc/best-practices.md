# Best Practices

1. **Dispose subscriptions** — Cancel the stream subscription in `dispose()` to avoid leaks.
2. **Handle initial state** — The stream emits once when you listen; handle that initial value in your UI.
3. **Show connectivity to users** — Especially when offline, so users know why some features don’t work.
4. **Graceful offline** — Design flows to work (or degrade) when connectivity is false instead of crashing.
