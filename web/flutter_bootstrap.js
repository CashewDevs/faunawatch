{{flutter_js}}
{{flutter_build_config}}

// Use software UI rendering to avoid CanvasKit stencil/shader failures.
// Mapbox owns a separate WebGL canvas and retains map acceleration.
_flutter.loader.load({
  config: {
    renderer: 'canvaskit',
    canvasKitForceCpuOnly: true,
  },
});
