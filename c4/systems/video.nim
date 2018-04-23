import sdl2.sdl
import "../wrappers/horde3d/horde3d"
import logging
import strformat

from os import getAppDir
import ospaths
import sequtils

import "../core/messages"
import "../systems"
import "../config"


type
  Window* = tuple[
    x, y, width, height: int,
    fullscreen: bool,
  ]

  VideoSystem* = object of System
    camera*: horde3d.Node
    window: sdl.Window
    pipelineResource, fontResource, panelResource: horde3d.Res

  Video* {.inheritable.} = object
    node*: horde3d.Node


let assetsDir = getAppDir() / "assets" / "video"


proc updateViewport*(self: ref VideoSystem, width, height: int) =
  ## Updates camera viewport
  self.camera.SetNodeParamI(horde3d.Camera.ViewportXI, 0)
  self.camera.SetNodeParamI(horde3d.Camera.ViewportYI, 0)
  self.camera.SetNodeParamI(horde3d.Camera.ViewportWidthI, width)
  self.camera.SetNodeParamI(horde3d.Camera.ViewportHeightI, height)
  self.camera.SetupCameraView(45.0, width.float / height.float, 0.5, 2048.0)

  self.pipelineResource.ResizePipelineBuffers(width, height)

proc loadResources*(self: ref VideoSystem) =
  logging.debug "Loading resources from " & assetsDir
  if not utLoadResourcesFromDisk(assetsDir):
    raise newException(LibraryError, "Could not load resources")

method init*(self: ref VideoSystem) =
  # ---- SDL ----
  logging.debug "Initializing SDL video system"

  let window = config.settings.video.window  # just an alias

  try:
    if sdl.initSubSystem(sdl.INIT_VIDEO) != 0:
      raise newException(LibraryError, "Could not init SDL video subsystem")

    # var displayMode: sdl.DisplayMode
    # if sdl.getCurrentDisplayMode(0, displayMode.addr) != 0:
    #   raise newException(LibraryError, "Could not get current display mode: " & $sdl.getError())
  
    self.window = sdl.createWindow(
      &"{config.title} v{config.version}",
      window.x,
      window.y,
      window.width,
      window.height,
      (sdl.WINDOW_SHOWN or sdl.WINDOW_OPENGL or sdl.WINDOW_RESIZABLE or (if window.fullscreen: sdl.WINDOW_FULLSCREEN_DESKTOP else: 0)).uint32,
    )
    if self.window == nil:
      raise newException(LibraryError, "Could not create SDL window")

    if sdl.glCreateContext(self.window) == nil:
      raise newException(LibraryError, "Could not create SDL OpenGL context")
    
    if sdl.setRelativeMouseMode(true) != 0:
      raise newException(LibraryError, "Could not enable relative mouse mode")

  except LibraryError:
    logging.fatal getCurrentExceptionMsg() & ": " & $sdl.getError()
    sdl.quitSubSystem(sdl.INIT_VIDEO)
    raise
    
  logging.debug "SDL video system initialized"

  # ---- Horde3d ----
  logging.debug "Initializing " & $horde3d.GetVersionString()

  try:
    if not horde3d.Init(horde3d.RenderDevice.OpenGL4):
      raise newException(LibraryError, "Could not init Horde3D: " & $horde3d.GetError())
  
    # load default resources
    self.pipelineResource = AddResource(ResTypes.Pipeline, "pipelines/forward.pipeline.xml")
    self.fontResource = AddResource(ResTypes.Material, "overlays/font.material.xml")
    self.panelResource = AddResource(ResTypes.Material,  "overlays/panel.material.xml")
    if @[self.pipelineResource, self.fontResource, self.panelResource].any(proc (res: Res): bool = res == 0):
      raise newException(LibraryError, "Could not add one or more resources")

    self.loadResources()

    # DEMO
    logging.debug "Adding light to the scene"
    var light = RootNode.AddLightNode("light", 0, "LIGHTING", "SHADOWMAP")
    light.SetNodeTransform(0.0, 20.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
    light.SetNodeParamF(Light.RadiusF, 0, 50.0)

    # setting up camera
    self.camera = horde3d.RootNode.AddCameraNode("camera", self.pipelineResource)
    self.updateViewport(window.width, window.height)

  except LibraryError:
    horde3d.Release()
    logging.fatal getCurrentExceptionMsg()
    raise

  logging.debug "Horde3d initialized"

  procCall ((ref System)self).init()

method update*(self: ref VideoSystem, dt: float) =
  procCall ((ref System)self).update(dt)

  if config.logLevel <= lvlDebug:
    horde3d.utShowFrameStats(self.fontResource, self.panelResource, 1)

  # self.model.UpdateModel(ModelUpdateFlags.Geometry)
  self.camera.Render()
  self.window.glSwapWindow()
  horde3d.FinalizeFrame()  # TODO: is this needed?
  horde3d.ClearOverlays()

{.experimental.}
method `=destroy`*(self: ref VideoSystem) {.base.} =
  sdl.quitSubSystem(sdl.INIT_VIDEO)
  horde3d.Release()
  logging.debug "Video system unloaded"

# ---- component ----
method init*(self: var Video) {.base.} =
  # self.node = RootNode.AddNodes(someRes)
  discard

method transform*(
  self: var Video,
  translation: tuple[x, y, z: float] = (0.0, 0.0, 0.0),
  rotation: tuple[x, y, z: float] = (0.0, 0.0, 0.0),
  scale: tuple[x, y, z: float] = (1.0, 1.0, 1.0)
) {.base.} =
  self.node.SetNodeTransform(
    translation.x, translation.y, translation.z,
    rotation.x, rotation.y, rotation.z,
    scale.x, scale.y, scale.z,
  )

method `=destroy`*(self: var Video) {.base.} =
  self.node.RemoveNode()
