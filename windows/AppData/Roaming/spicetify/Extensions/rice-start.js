// Spicetify extension (enabled by run_after_77-spicetify.ps1), on Spotify's start:
//   - open a playlist instead of Home (default: Spotify's "lofi beats")
//   - shrink the native title bar to 1px: its minimize/maximize/close buttons sit on a translucent
//     black background that no CSS can restyle (GlazeWM handles the windows anyway: alt+shift+q)
(function riceStart() {
    const playlist = "37i9dQZF1DWWQRwui0ExPn";
    const platform = Spicetify?.Platform;
    if (!platform?.History || !platform?.ControlMessageAPI) {
        setTimeout(riceStart, 300);
        return;
    }
    platform.History.push(`/playlist/${playlist}`);

    // Spotify sets the height again on some layout changes; keep it at 1px
    const shrink = () => platform.ControlMessageAPI.setTitlebarHeight(1).catch(() => {});
    shrink();
    window.addEventListener("resize", shrink);
    setInterval(shrink, 5000);
})();
